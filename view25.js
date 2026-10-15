/* Stellar Horizons 2.5D view: a dependency-free WebGL2 renderer.
   It draws the same game state as the flat map (positions come from the flat painter's draw calls), with a tilted
   perspective camera, a starfield, spinning planets, hovering counters and flat world cards.
   Public API: V25.on, V25.toggle(), V25.frame(), V25.sprite/text/ring/poly/box (called by the flat painter), V25.pick, ... */
(function () {
  'use strict';
  const V = window.V25 = { on: false, ok: null, mode: 'flat', lift: 0 };
  let gl, cvs, pQ, pP, vbo, W = 1, H = 1, dpr = 1, ready = false;
  const texs = new Map();
  const C = { tx: 1500, tz: 900, yaw: 0, pitch: .98, dist: 2400 };
  const FOV = .72, NEAR = 20, FAR = 90000;
  let eye = [0, 0, 0], fwd = [0, 0, -1], rgt = [1, 0, 0], cup = [0, 1, 0], vp = new Float32Array(16);
  let rec = [], gfx = [], stars = null, planetTex = null, sunInfo = null, ovInfo = null, picks = [], lastHover = null;
  const sunPos = [350, 0, 1750];

  // ---------- small math ----------
  const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const norm = a => { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };
  const mul = (a, b) => { const o = new Float32Array(16); for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) { let s = 0; for (let k = 0; k < 4; k++) s += a[k * 4 + j] * b[i * 4 + k]; o[i * 4 + j] = s; } return o; };
  function setupCam() {
    const cp = Math.cos(C.pitch), sp = Math.sin(C.pitch);
    eye = [C.tx + C.dist * cp * Math.sin(C.yaw), C.dist * sp, C.tz + C.dist * cp * Math.cos(C.yaw)];
    const z = norm(sub(eye, [C.tx, 0, C.tz]));
    rgt = norm(cross([0, 1, 0], z)); cup = cross(z, rgt); fwd = [-z[0], -z[1], -z[2]];
    const view = new Float32Array([rgt[0], cup[0], z[0], 0, rgt[1], cup[1], z[1], 0, rgt[2], cup[2], z[2], 0, -dot(rgt, eye), -dot(cup, eye), -dot(z, eye), 1]);
    const f = 1 / Math.tan(FOV / 2), a = W / H;
    const pr = new Float32Array([f / a, 0, 0, 0, 0, f, 0, 0, 0, 0, (FAR + NEAR) / (NEAR - FAR), -1, 0, 0, 2 * FAR * NEAR / (NEAR - FAR), 0]);
    vp = mul(pr, view);
  }
  function proj(x, y, z) {
    const m = vp, cx = m[0] * x + m[4] * y + m[8] * z + m[12], cy = m[1] * x + m[5] * y + m[9] * z + m[13], cw = m[3] * x + m[7] * y + m[11] * z + m[15];
    if (cw <= 0) return null;
    return [(cx / cw * .5 + .5) * W, (1 - (cy / cw * .5 + .5)) * H, cw];
  }
  function ray(sx, sy) {
    const t = Math.tan(FOV / 2), nx = sx / W * 2 - 1, ny = 1 - sy / H * 2, a = W / H;
    return norm([fwd[0] + rgt[0] * nx * t * a + cup[0] * ny * t, fwd[1] + rgt[1] * nx * t * a + cup[1] * ny * t, fwd[2] + rgt[2] * nx * t * a + cup[2] * ny * t]);
  }
  function ground(sx, sy, h) {
    const d = ray(sx, sy), y0 = h || 0; if (d[1] > -1e-4) return null;
    const s = (y0 - eye[1]) / d[1]; return { x: eye[0] + d[0] * s, y: eye[2] + d[2] * s };
  }

  // ---------- GL setup ----------
  const VS = `attribute vec3 p;attribute vec2 uv;attribute vec2 q;attribute vec4 c;uniform mat4 M;uniform float PT;
    varying vec2 vuv;varying vec2 vq;varying vec4 vc;void main(){vuv=uv;vq=q;vc=c;gl_Position=M*vec4(p,1.);gl_PointSize=PT;}`;
  const FSQ = `precision highp float;varying vec2 vuv;varying vec2 vq;varying vec4 vc;uniform sampler2D T;uniform int MODE;
    void main(){
      if(MODE==0){vec4 t=texture2D(T,vuv);gl_FragColor=vec4(t.rgb*vc.rgb,t.a*vc.a);}
      else if(MODE==1){gl_FragColor=vc;}
      else if(MODE==2){float d=length(vq*2.-1.);float a=smoothstep(1.,.8,d);gl_FragColor=vec4(vc.rgb,vc.a*a);}
      else if(MODE==3){float d=length(vq*2.-1.);float a=pow(max(0.,1.-d),2.);gl_FragColor=vec4(vc.rgb,vc.a*a);}
      else {float d=length(gl_PointCoord*2.-1.);float a=smoothstep(1.,.2,d);gl_FragColor=vec4(vc.rgb,vc.a*a);}
    }`;
  const FSP = `precision highp float;varying vec2 vq;uniform sampler2D T;uniform float row,rot,AW,AH,TW,TH,DS;uniform vec3 L;
    void main(){vec2 q=vec2(vq.x*2.-1.,vq.y*2.-1.);float d=length(q);if(d>1.)discard;
      float lat=asin(clamp(q.y,-1.,1.));float cl=max(cos(lat),1e-3);float lon=asin(clamp(q.x/cl,-1.,1.))+rot;
      float u=fract((lon+3.14159265)/6.2831853);float vv=(lat+1.5707963)/3.14159265;
      vec3 c=texture2D(T,vec2(u*TW/AW,(row*TH+vv*TH)/AH)).rgb;
      vec4 m=texture2D(T,vec2((TW+(q.x*.5+.5)*DS)/AW,(row*TH+(q.y*.5+.5)*DS)/AH));
      float a=m.a*smoothstep(1.,.97,d);
      vec3 n=vec3(q.x,-q.y,sqrt(max(0.,1.-d*d)));float lam=max(0.,dot(n,normalize(L)));
      float sh=.32+.95*lam;
      gl_FragColor=vec4(c*m.r*1.55*sh*a,a);}`;
  function prog(vs, fs) {
    const mk = (t, s) => { const o = gl.createShader(t); gl.shaderSource(o, s); gl.compileShader(o); if (!gl.getShaderParameter(o, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(o)); return o; };
    const p = gl.createProgram(); gl.attachShader(p, mk(gl.VERTEX_SHADER, vs)); gl.attachShader(p, mk(gl.FRAGMENT_SHADER, fs)); gl.bindAttribLocation(p, 0, 'p'); gl.bindAttribLocation(p, 1, 'uv'); gl.bindAttribLocation(p, 2, 'q'); gl.bindAttribLocation(p, 3, 'c'); gl.linkProgram(p);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p));
    const u = {}; ['M', 'PT', 'T', 'MODE', 'row', 'rot', 'AW', 'AH', 'TW', 'TH', 'DS', 'L'].forEach(n => u[n] = gl.getUniformLocation(p, n)); p.u = u; return p;
  }
  const STRIDE = 11 * 4;
  function attribs() {
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    [[0, 3, 0], [1, 2, 12], [2, 2, 20], [3, 4, 28]].forEach(([i, n, o]) => { gl.enableVertexAttribArray(i); gl.vertexAttribPointer(i, n, gl.FLOAT, false, STRIDE, o); });
  }
  function texOf(img, mip, wrap) {
    let t = texs.get(img); if (t) return t;
    t = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, t);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false); gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, img);
    const wr = wrap ? gl.REPEAT : gl.CLAMP_TO_EDGE; gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, wr); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, wr);
    if (mip) { gl.generateMipmap(gl.TEXTURE_2D); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR); const an = gl.getExtension('EXT_texture_filter_anisotropic'); if (an) gl.texParameterf(gl.TEXTURE_2D, an.TEXTURE_MAX_ANISOTROPY_EXT, 8); }
    else gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    texs.set(img, t); return t;
  }
  function reupload(img) { const t = texs.get(img); if (!t) return; gl.bindTexture(gl.TEXTURE_2D, t); gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false); gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, img); }

  V.init = function (stage, before) {
    try {
      cvs = document.createElement('canvas'); cvs.id = 'gl25'; cvs.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block;touch-action:none';
      stage.insertBefore(cvs, before || null);
      gl = cvs.getContext('webgl2', { antialias: true, alpha: false, premultipliedAlpha: false });
      if (!gl) throw new Error('WebGL2 is not available');
      pQ = prog(VS, FSQ); pP = prog(VS, FSP);
      vbo = gl.createBuffer(); attribs();
      gl.enable(gl.BLEND); gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA); gl.disable(gl.DEPTH_TEST);
      // stars: below and around the board, so the gaps between map sheets and the edges show depth
      const r = mulb(777), pts = [];
      for (let i = 0; i < 2600; i++) {
        const x = -9000 + r() * 24000, z = -9000 + r() * 22000, y = -(300 + r() * 7000), b = .35 + r() * .65, h = r();
        pts.push(x, y, z, 0, 0, 0, 0, h < .12 ? .7 : 1, h < .12 ? .8 : (h > .88 ? .75 : 1), h < .12 ? 1 : (h > .88 ? .6 : 1), b);
      }
      stars = new Float32Array(pts);
      ready = true; V.ok = true;
    } catch (e) { V.ok = false; V.err = e.message; console.warn('2.5D view unavailable:', e.message); }
    return V.ok;
  };
  function mulb(a) { return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
  V.setBodies = img => { planetTex = img; };
  V.setSun = c => { sunInfo = c; };
  V.setOverlay = (c, k) => { if (ovInfo && ovInfo.c === c) { ovInfo.k = k; ovInfo.dirty = true; } else ovInfo = { c, k, dirty: true }; };

  V.resize = function (w, h, d) {
    if (!cvs) return; dpr = Math.min(2, d || 1); W = Math.max(1, w); H = Math.max(1, h);
    cvs.width = Math.round(W * dpr); cvs.height = Math.round(H * dpr);
  };

  // ---------- recording (called by the flat painter while 2.5D is on) ----------
  V.begin = function () { rec = []; gfx = []; V.mode = 'flat'; V.lift = 0; };
  V.sprite = function (img, f, x, y, size, a) {
    if (!f || !img) return;
    const k = size / Math.max(f[2], f[3]);
    rec.push({ k: 's', img, f, x, y, w: f[2] * k, h: f[3] * k, a: a || 0, mode: V.mode, lift: V.lift });
  };
  const tcache = new Map();
  V.text = function (t, x, y, size, color, align) {
    const key = t + '|' + color + '|' + Math.round(size);
    let c = tcache.get(key);
    if (!c) {
      const cv2 = document.createElement('canvas'), x2 = cv2.getContext('2d'), fs = Math.max(14, Math.round(size * 2));
      x2.font = `600 ${fs}px "IBM Plex Sans Condensed","Arial Narrow",sans-serif`; const w = Math.ceil(x2.measureText(t).width) + 12;
      cv2.width = w; cv2.height = Math.round(fs * 1.4); x2.font = `600 ${fs}px "IBM Plex Sans Condensed","Arial Narrow",sans-serif`; x2.textAlign = 'center'; x2.textBaseline = 'middle';
      x2.lineWidth = Math.max(3, fs / 5); x2.lineJoin = 'round'; x2.strokeStyle = '#000'; x2.strokeText(t, w / 2, cv2.height / 2); x2.fillStyle = color; x2.fillText(t, w / 2, cv2.height / 2);
      c = { cv: cv2, w: w / 2 * (size / (fs / 2)), h: cv2.height / 2 * (size / (fs / 2)) }; if (tcache.size > 500) tcache.clear(); tcache.set(key, c);
    }
    const off = align === 'left' ? c.w / 2 : align === 'right' ? -c.w / 2 : 0;
    rec.push({ k: 's', img: c.cv, f: [0, 0, c.cv.width, c.cv.height], x: x + off, y, w: c.w, h: c.h, a: 0, mode: V.mode, lift: V.lift + (V.mode === 'stand' ? 18 : 0), text: true });
  };
  // ground decorations
  V.ring = (x, y, r, color, w) => gfx.push({ k: 'ring', x, y, r, color, w: w || 3 });
  V.poly = (pts, color, w, fill) => gfx.push({ k: 'poly', pts, color, w: w || 3, fill });
  V.box = (x, y, s, a, color, w) => { const h = s / 2, c = Math.cos(a), sn = Math.sin(a); V.poly([[-h, -h], [h, -h], [h, h], [-h, h]].map(([u, v]) => [x + u * c - v * sn, y + u * sn + v * c]), color, w || 3); };

  // ---------- geometry builders ----------
  const parse = col => {
    if (Array.isArray(col)) return col;
    if (col[0] === '#') { const n = col.length === 4 ? col.slice(1).split('').map(c => parseInt(c + c, 16)) : [1, 3, 5].map(i => parseInt(col.slice(i, i + 2), 16)); return [n[0] / 255, n[1] / 255, n[2] / 255, 1]; }
    const m = col.match(/[\d.]+/g).map(Number); return [m[0] / 255, m[1] / 255, m[2] / 255, m.length > 3 ? m[3] : 1];
  };
  function pv(a, x, y, z, u, v, qx, qy, c) { a.push(x, y, z, u, v, qx, qy, c[0], c[1], c[2], c[3]); }
  function quad(a, P, uv, c) { // P: TL,TR,BR,BL
    const Q = [[0, 0], [1, 0], [1, 1], [0, 1]], U = [[uv[0], uv[1]], [uv[2], uv[1]], [uv[2], uv[3]], [uv[0], uv[3]]];
    [0, 1, 2, 0, 2, 3].forEach(i => pv(a, P[i][0], P[i][1], P[i][2], U[i][0], U[i][1], Q[i][0], Q[i][1], c));
  }
  function flatQuad(a, x, y, w, h, ang, yy, uv, c) {
    const co = Math.cos(ang), si = Math.sin(ang), pt = (u, v) => [x + u * co - v * si, yy, y + u * si + v * co];
    quad(a, [pt(-w / 2, -h / 2), pt(w / 2, -h / 2), pt(w / 2, h / 2), pt(-w / 2, h / 2)], uv, c);
  }
  function ribbon(a, pts, closed, w, yy, c) {
    const n = pts.length, m = closed ? n : n - 1;
    for (let i = 0; i < m; i++) {
      const p0 = pts[i], p1 = pts[(i + 1) % n], dx = p1[0] - p0[0], dy = p1[1] - p0[1], l = Math.hypot(dx, dy) || 1, nx = -dy / l * w / 2, ny = dx / l * w / 2;
      quad(a, [[p0[0] + nx, yy, p0[1] + ny], [p1[0] + nx, yy, p1[1] + ny], [p1[0] - nx, yy, p1[1] - ny], [p0[0] - nx, yy, p0[1] - ny]], [0, 0, 1, 1], c);
      if (closed || i > 0) { const q = [p0[0] + nx, p0[1] + ny]; /* tiny joint patch */ const r = w * .5; flatQuad(a, p0[0], p0[1], r * 1.4, r * 1.4, 0, yy, [0, 0, 1, 1], c); }
    }
  }
  function earclip(P) { // simple ear clipping, returns triangle index list
    const n = P.length; if (n < 3) return [];
    let area = 0; for (let i = 0; i < n; i++) { const a = P[i], b = P[(i + 1) % n]; area += a[0] * b[1] - b[0] * a[1]; }
    const idx = [...Array(n).keys()]; if (area < 0) idx.reverse();
    const out = [], cr = (a, b, c) => (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
    const inT = (p, a, b, c) => cr(a, b, p) >= 0 && cr(b, c, p) >= 0 && cr(c, a, p) >= 0;
    let guard = n * n;
    while (idx.length > 3 && guard-- > 0) {
      let cut = false;
      for (let i = 0; i < idx.length; i++) {
        const i0 = idx[(i + idx.length - 1) % idx.length], i1 = idx[i], i2 = idx[(i + 1) % idx.length], a = P[i0], b = P[i1], c = P[i2];
        if (cr(a, b, c) <= 0) continue;
        if (idx.some(j => j !== i0 && j !== i1 && j !== i2 && inT(P[j], a, b, c))) continue;
        out.push(i0, i1, i2); idx.splice(i, 1); cut = true; break;
      }
      if (!cut) break;
    }
    if (idx.length === 3) out.push(idx[0], idx[1], idx[2]);
    return out;
  }
  function fillPoly(a, pts, yy, c) { const t = earclip(pts); for (let i = 0; i < t.length; i += 3) for (let k = 0; k < 3; k++) { const p = pts[t[i + k]]; pv(a, p[0], yy, p[1], 0, 0, 0, 0, c); } }
  const circlePts = (cx, cy, r, n) => Array.from({ length: n || 48 }, (_, i) => [cx + Math.cos(i / (n || 48) * 6.2832) * r, cy + Math.sin(i / (n || 48) * 6.2832) * r]);

  // ---------- drawing ----------
  let seg = [];
  function flush(prog_, verts, tex, mode, mipwrap) {
    if (!verts.length) return;
    gl.useProgram(prog_); gl.uniformMatrix4fv(prog_.u.M, false, vp);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(verts), gl.DYNAMIC_DRAW);
    if (tex) { gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, tex); gl.uniform1i(prog_.u.T, 0); }
    gl.uniform1i(prog_.u.MODE, mode); gl.uniform1f(prog_.u.PT, 1);
    gl.drawArrays(gl.TRIANGLES, 0, verts.length / 11);
  }
  // group consecutive draws that share a texture and mode
  function batch(list) { // list of {tex, mode, verts[]}
    let cur = null;
    const end = () => { if (cur) flush(pQ, cur.verts, cur.tex, cur.mode); cur = null; };
    for (const it of list) { if (cur && cur.tex === it.tex && cur.mode === it.mode) { for (let i = 0; i < it.verts.length; i++) cur.verts.push(it.verts[i]); } else { end(); cur = { tex: it.tex, mode: it.mode, verts: it.verts.slice() }; } }
    end();
  }
  const WHITE = [1, 1, 1, 1];
  function frame() {
    if (!ready || !V.on) return;
    setupCam();
    gl.viewport(0, 0, cvs.width, cvs.height); gl.clearColor(.012, .02, .04, 1); gl.clear(gl.COLOR_BUFFER_BIT);
    // 1 stars
    gl.useProgram(pQ); gl.uniformMatrix4fv(pQ.u.M, false, vp); gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(stars), gl.DYNAMIC_DRAW); gl.uniform1i(pQ.u.MODE, 4); gl.uniform1f(pQ.u.PT, 2.2 * dpr);
    gl.drawArrays(gl.POINTS, 0, stars.length / 11);
    // nebula wash, a huge tiled plane well below the board
    if (typeof FX !== 'undefined' && FX.neb) {
      const a = [], S = 60000, rep = S / 2600; flatQuad(a, 2600, 2300, S, S, 0, -2200, [0, 0, rep, rep], [1, 1, 1, .9]);
      flush(pQ, a, texOf(FX.neb, false, true), 0);
    }
    // 2 map sheets, explore overlay, sun
    const ground1 = [];
    Object.entries(GEO.maps).forEach(([c, [x, y, w, h]]) => { if (!IMG.maps[c]) return; const a = []; flatQuad(a, x + w / 2, y + h / 2, w, h, 0, 0, [0, 0, 1, 1], WHITE); ground1.push({ tex: texOf(IMG.maps[c], true), mode: 0, verts: a }); });
    batch(ground1);
    // glowing edge around each sheet
    { const a = []; Object.values(GEO.maps).forEach(([x, y, w, h]) => ribbon(a, [[x, y], [x + w, y], [x + w, y + h], [x, y + h]], true, 10, .5, [.31, .76, .85, .35])); flush(pQ, a, null, 1); }
    if (sunInfo) { const S = FX.sun, m = GEO.maps[S.map], cx = m[0] + S.cx * .4, cy = m[1] + S.cy * .4, r = S.r * .4, edge = m[1] + m[3], X0 = cx - r * 1.25, Y0 = cy - r * 1.18, Wd = r * 2.5, Hd = edge + 170 - Y0; sunPos[0] = cx; sunPos[2] = cy; const a = []; flatQuad(a, X0 + Wd / 2, Y0 + Hd / 2, Wd, Hd, 0, 1, [0, 0, 1, 1], WHITE); reupload(sunInfo); flush(pQ, a, texOf(sunInfo, false), 0); }
    if (ovInfo) { const t = texOf(ovInfo.c, false); if (ovInfo.dirty) { reupload(ovInfo.c); ovInfo.dirty = false; } const a = [], w = ovInfo.c.width / ovInfo.k, h = ovInfo.c.height / ovInfo.k; flatQuad(a, w / 2, h / 2, w, h, 0, 1.2, [0, 0, 1, 1], WHITE); flush(pQ, a, t, 0); }
    // 3 ground decorations: orbit rings, selections, drag targets
    {
      const a = [], fill = [], dots = [];
      if (G) Object.keys(GEO.worlds).forEach(w => {
        if (!G.w[w] || !GEO.worlds[w].poly || !DOTR[w]) return;
        const R = ringOf(w), n = Math.round(2 * Math.PI * R.r / 9);
        for (let i = 0; i < n; i++) { const an = i / n * 2 * Math.PI; flatQuad(dots, R.c[0] + Math.cos(an) * R.r, R.c[1] + Math.sin(an) * R.r, 5, 5, 0, 2, [0, 0, 1, 1], [.59, .52, .84, .9]); }
      });
      gfx.forEach(g => {
        const c = parse(g.color);
        if (g.k === 'ring') ribbon(a, circlePts(g.x, g.y, g.r, 40), true, g.w * 1.4, 3, c);
        else if (g.k === 'poly') { if (g.fill) fillPoly(fill, g.pts, 2.5, parse(g.fill)); ribbon(a, g.pts, true, g.w * 1.4, 3, c); }
      });
      if (typeof targets !== 'undefined' && targets) {
        const seen = new Set(), dests = new Set(targets.map(m => m.dest));
        targets.forEach(m => {
          if (seen.has(m.dest)) return; seen.add(m.dest);
          const p = E.P(m.dest), z = zoneShape(m.dest, p.t === 'orbit' && dests.has('surf:' + p.w)), pts = z.poly ? z.poly : circlePts(z.c[0], z.c[1], z.r, 36);
          fillPoly(fill, pts, 2.6, [.31, .76, .85, .2]); ribbon(a, pts, true, 7, 3.2, [.31, .76, .85, .95]); if (z.hole) ribbon(a, z.hole, true, 5, 3.2, [.31, .76, .85, .8]);
        });
      }
      flush(pQ, dots, null, 2); flush(pQ, fill, null, 1); flush(pQ, a, null, 1);
    }
    // 4 flat sprites (world cards, base counters, trade markers)
    const flat = [], stand = [];
    rec.forEach(r => { (r.mode === 'stand' ? stand : flat).push(r); });
    {
      const list = [];
      flat.forEach(r => {
        const a = [], iw = r.img.width, ih = r.img.height, uv = [r.f[0] / iw, r.f[1] / ih, (r.f[0] + r.f[2]) / iw, (r.f[1] + r.f[3]) / ih];
        flatQuad(a, r.x, r.y, r.w, r.h, r.a, r.text ? 6 : 4, uv, WHITE); list.push({ tex: texOf(r.img, false), mode: 0, verts: a });
      });
      batch(list);
    }
    // 5 standing items, far to near: planets, counters, labels
    picks = [];
    const items = [];
    const B = typeof FX !== 'undefined' && FX.bodies;
    if (B && planetTex && G) Object.entries(B.b).forEach(([k, b]) => {
      const m = GEO.maps[b.map], x = m[0] + b.cx * .4, z = m[1] + b.cy * .4, r = b.r * .4, y = r * .55;
      items.push({ t: 'planet', k, b, x, y, z, r, d: (x - eye[0]) ** 2 + (y - eye[1]) ** 2 + (z - eye[2]) ** 2 });
    });
    stand.forEach(r => {
      const lift = (r.lift || 0), y = lift + r.h / 2;
      items.push({ t: 'spr', r, x: r.x, y, z: r.y, d: (r.x - eye[0]) ** 2 + (y - eye[1]) ** 2 + (r.y - eye[2]) ** 2 });
    });
    items.sort((p, q) => q.d - p.d);
    // soft shadows on the board under everything that hovers
    { const a = []; items.forEach(it => { if (it.t === 'planet') flatQuad(a, it.x, it.z, it.r * 2.1, it.r * 1.2, 0, 1.6, [0, 0, 1, 1], [0, 0, 0, .38]); else if (!it.r.text) flatQuad(a, it.r.x, it.r.y, it.r.w * .9, it.r.w * .5, 0, 1.6, [0, 0, 1, 1], [0, 0, 0, .4]); }); flush(pQ, a, null, 2); }
    let run = [];
    const flushRun = () => { batch(run); run = []; };
    items.forEach(it => {
      if (it.t === 'planet') {
        flushRun();
        const R = [rgt[0] * it.r, rgt[1] * it.r, rgt[2] * it.r], U = [cup[0] * it.r, cup[1] * it.r, cup[2] * it.r];
        const a = [], P = [[it.x - R[0] + U[0], it.y - R[1] + U[1], it.z - R[2] + U[2]], [it.x + R[0] + U[0], it.y + R[1] + U[1], it.z + R[2] + U[2]], [it.x + R[0] - U[0], it.y + R[1] - U[1], it.z + R[2] - U[2]], [it.x - R[0] - U[0], it.y - R[1] - U[1], it.z - R[2] - U[2]]];
        quad(a, P, [0, 0, 1, 1], WHITE);
        gl.useProgram(pP); gl.uniformMatrix4fv(pP.u.M, false, vp); gl.bindBuffer(gl.ARRAY_BUFFER, vbo); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(a), gl.DYNAMIC_DRAW);
        gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, texOf(planetTex, false)); gl.uniform1i(pP.u.T, 0);
        const u = pP.u; gl.uniform1f(u.AW, planetTex.width); gl.uniform1f(u.AH, planetTex.height); gl.uniform1f(u.TW, B.tw); gl.uniform1f(u.TH, B.th); gl.uniform1f(u.DS, B.ds);
        gl.uniform1f(u.row, it.b.row); gl.uniform1f(u.rot, ((FX.t || 0) * 6.2832 / it.b.spd) % 6.2832);
        const Ld = norm(sub(sunPos, [it.x, 0, it.z])); gl.uniform3f(u.L, dot(Ld, rgt), dot(Ld, cup) * .6 + .25, .55);
        gl.drawArrays(gl.TRIANGLES, 0, 6);
        gl.useProgram(pQ);
        // pickable
        const c = proj(it.x, it.y, it.z), e = proj(it.x + rgt[0] * it.r, it.y + rgt[1] * it.r, it.z + rgt[2] * it.r);
        if (c && e) picks.push({ sx: c[0], sy: c[1], pr: Math.hypot(e[0] - c[0], e[1] - c[1]), hit: { t: 'world', k: it.k }, z: c[2], planet: true });
      } else {
        const r = it.r, iw = r.img.width, ih = r.img.height, uv = [r.f[0] / iw, r.f[1] / ih, (r.f[0] + r.f[2]) / iw, (r.f[1] + r.f[3]) / ih];
        const hw = r.w / 2, l = r.lift || 0, bob = r.text ? 0 : Math.sin((FX.t || 0) * 1.3 + r.x * .013 + r.y * .017) * 3;
        const bx = r.x, by = l + bob, bz = r.y, uh = [cup[0] * r.h, cup[1] * r.h, cup[2] * r.h];
        const P = [[bx - rgt[0] * hw + uh[0], by + uh[1], bz - rgt[2] * hw + uh[2]], [bx + rgt[0] * hw + uh[0], by + uh[1], bz + rgt[2] * hw + uh[2]], [bx + rgt[0] * hw, by, bz + rgt[2] * hw], [bx - rgt[0] * hw, by, bz - rgt[2] * hw]];
        const a = []; quad(a, P, uv, WHITE); run.push({ tex: texOf(r.img, false), mode: 0, verts: a });
        if (!r.text) {
          const c = proj(r.x + cup[0] * r.h / 2, l + bob + cup[1] * r.h / 2, r.y + cup[2] * r.h / 2), e = proj(r.x + rgt[0] * r.w / 2 + cup[0] * r.h / 2, l + bob + cup[1] * r.h / 2, r.y + rgt[2] * r.w / 2 + cup[2] * r.h / 2);
          if (c && e) picks.push({ sx: c[0], sy: c[1], pr: Math.hypot(e[0] - c[0], e[1] - c[1]), x: r.x, y: r.y, z: c[2], rec: r });
        }
      }
    });
    flushRun();
  }
  V.frame = frame;

  // match standing sprites to the flat painter's hit list (so a tap selects the same thing as in the flat view)
  V.finish = function (hitsList) {
    rec.forEach(r => { if (r.mode !== 'stand' || r.text) return; r.hit = null; for (let i = hitsList.length - 1; i >= 0; i--) { const h = hitsList[i]; if ((h.t === 'ship' || h.t === 'oship') && Math.abs(h.x - r.x) < 1.5 && Math.abs(h.y - r.y) < 1.5) { r.hit = h; break; } } });
  };
  V.pick = function (sx, sy, wantDrag) {
    let best = null;
    for (const p of picks) {
      if (Math.hypot(sx - p.sx, sy - p.sy) > Math.max(p.pr, 9)) continue;
      const hit = p.planet ? p.hit : (p.rec && p.rec.hit);
      if (!hit) continue;
      if (!best || p.z < best.z) best = { z: p.z, hit };
    }
    if (best) return { hit: best.hit, p: null };
    const g = ground(sx, sy, 0);
    return { hit: g && typeof hitAtWorld === 'function' ? hitAtWorld(g) : null, p: g };
  };
  V.ground = ground;

  // ---------- camera control ----------
  const clampCam = () => { C.pitch = Math.max(.35, Math.min(1.3, C.pitch)); C.dist = Math.max(250, Math.min(9000, C.dist)); C.tx = Math.max(-400, Math.min(5800, C.tx)); C.tz = Math.max(-400, Math.min(5200, C.tz)); };
  V.zoom = f => { C.dist /= f; clampCam(); dirtyIt(); };
  V.rotate = (dy, dp) => { C.yaw += dy; C.pitch += dp; clampCam(); dirtyIt(); };
  V.focus = (p, s) => { C.tx = p[0]; C.tz = p[1]; if (s) C.dist = Math.max(300, 1500 / Math.max(.3, s)); clampCam(); dirtyIt(); };
  V.fit = () => { C.tx = 2650; C.tz = 2300; C.dist = 7600; C.yaw = 0; C.pitch = 1.05; clampCam(); dirtyIt(); };
  V.home = p => { C.tx = p[0]; C.tz = p[1] + 150; C.dist = 2300; C.pitch = .98; C.yaw = 0; clampCam(); dirtyIt(); };
  V.cam = C;
  const dirtyIt = () => { if (typeof dirty !== 'undefined') dirty = true; };
  V.panBy = (p0, sx, sy) => { const p1 = ground(sx, sy, 0); if (!p1 || !p0) return; C.tx += p0.x - p1.x; C.tz += p0.y - p1.y; clampCam(); dirtyIt(); };
  V.picks = () => picks;
  V.toScreen = (x, y, z) => proj(x, y, z);
  V.canvas = () => cvs;
  V.show = on => { if (cvs) cvs.style.display = on ? 'block' : 'none'; };
})();
