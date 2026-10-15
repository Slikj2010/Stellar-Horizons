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
  const FSQ = `precision highp float;varying vec2 vuv;varying vec2 vq;varying vec4 vc;uniform sampler2D T;uniform int MODE;uniform float TM;
    float hh(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
    float vn(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hh(i),hh(i+vec2(1.,0.)),f.x),mix(hh(i+vec2(0.,1.)),hh(i+vec2(1.,1.)),f.x),f.y);}
    void main(){
      if(MODE==0){vec4 t=texture2D(T,vuv);gl_FragColor=vec4(t.rgb*vc.rgb,t.a*vc.a);}
      else if(MODE==1){gl_FragColor=vc;}
      else if(MODE==2){float d=length(vq*2.-1.);float a=smoothstep(1.,.8,d);gl_FragColor=vec4(vc.rgb,vc.a*a);}
      else if(MODE==3){float d=length(vq*2.-1.);float a=pow(max(0.,1.-d),2.);gl_FragColor=vec4(vc.rgb,vc.a*a);}
      else if(MODE==6){vec4 t=texture2D(T,vuv);float f=smoothstep(0.,.06,min(min(vq.x,1.-vq.x),min(vq.y,1.-vq.y)));gl_FragColor=vec4(t.rgb,t.a*f);}
      else if(MODE==8){vec2 g=abs(fract(vuv)-.5);float line=smoothstep(.44,.5,max(g.x,g.y));
        float scan=smoothstep(.2,1.,sin(TM*1.3+vuv.x*.45+vuv.y*.3))*.16;
        vec3 c=vc.rgb+vec3(.02,.22,.32)*(line*.55+scan);gl_FragColor=vec4(c,vc.a);}
      else if(MODE==7){vec2 q=vq*2.-1.;float d=length(q);if(d>1.)discard;
        float n=vn(q*4.+TM*.05)*.5+vn(q*9.-TM*.08)*.3+vn(q*21.+TM*.03)*.2;
        vec3 c=mix(vec3(1.,.55,.14),vec3(1.,.93,.6),n);c=mix(c,vec3(1.,.97,.8),.35*(1.-d));c*=1.-.35*pow(d,2.5);
        c+=vec3(.45,.18,.02)*smoothstep(.8,1.,d);
        gl_FragColor=vec4(c,smoothstep(1.,.97,d));}
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
    const u = {}; ['M', 'PT', 'T', 'MODE', 'TM', 'row', 'rot', 'AW', 'AH', 'TW', 'TH', 'DS', 'L'].forEach(n => u[n] = gl.getUniformLocation(p, n)); p.u = u; return p;
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
  function flush(prog_, verts, tex, mode) {
    if (!verts.length) return;
    gl.useProgram(prog_); gl.uniformMatrix4fv(prog_.u.M, false, vp);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(verts), gl.DYNAMIC_DRAW);
    if (tex) { gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, tex); gl.uniform1i(prog_.u.T, 0); }
    gl.uniform1i(prog_.u.MODE, mode); gl.uniform1f(prog_.u.PT, 1); gl.uniform1f(prog_.u.TM, (typeof FX !== 'undefined' && FX.t) || 0);
    gl.drawArrays(gl.TRIANGLES, 0, verts.length / 11);
  }
  function batch(list) { // consecutive draws that share a texture and mode become one call
    let cur = null;
    const end = () => { if (cur) flush(pQ, cur.verts, cur.tex, cur.mode); cur = null; };
    for (const it of list) { if (cur && cur.tex === it.tex && cur.mode === it.mode) { for (let i = 0; i < it.verts.length; i++) cur.verts.push(it.verts[i]); } else { end(); cur = { tex: it.tex, mode: it.mode, verts: it.verts.slice() }; } }
    end();
  }
  const WHITE = [1, 1, 1, 1];
  let LAY = null, belts = null, sky = null, labelTex = new Map(), ERASED = null;
  // the printed transfer and flyby boxes are painted out of the sheets; the 3D models below take their place
  const boxPolys = () => { const out = []; Object.entries(GEO.sys).forEach(([k, sy]) => { Object.entries(sy.boxPoly).forEach(([n, q]) => out.push({ k, n, id: 'box:' + k + ':' + n, pts: q, fly: false })); out.push({ k, n: 'fly', id: 'fly:' + k, pts: hull(sy.flybyPoly), fly: true }); }); return out; };
  function eraseSheets() {
    ERASED = {}; const polys = boxPolys();
    Object.entries(GEO.maps).forEach(([c, [x, y, w, h]]) => {
      const img = IMG.maps[c]; if (!img) return;
      const k = img.width / w, cv2 = document.createElement('canvas'); cv2.width = img.width; cv2.height = img.height;
      const x2 = cv2.getContext('2d'); x2.drawImage(img, 0, 0); x2.fillStyle = '#04070d'; x2.shadowColor = '#04070d'; x2.shadowBlur = 10 * k;
      polys.forEach(P => {
        let cx = 0, cy = 0; P.pts.forEach(q => { cx += q[0]; cy += q[1]; }); cx /= P.pts.length; cy /= P.pts.length;
        x2.beginPath(); P.pts.forEach(([px, py], i) => { const X = (cx + (px - cx) * 1.16 - x) * k, Y = (cy + (py - cy) * 1.16 - y) * k; i ? x2.lineTo(X, Y) : x2.moveTo(X, Y); }); x2.closePath(); x2.fill();
      });
      ERASED[c] = cv2;
    });
  }
  const glyphs = new Map();
  function glyph(t, col) {
    const key = t + col; let c = glyphs.get(key); if (c) return c;
    const cv2 = document.createElement('canvas'); cv2.width = 160; cv2.height = 160; const x2 = cv2.getContext('2d');
    x2.font = '700 ' + (t.length > 2 ? 40 : 104) + 'px "IBM Plex Sans Condensed","Arial Narrow",sans-serif'; x2.textAlign = 'center'; x2.textBaseline = 'middle';
    x2.shadowColor = col; x2.shadowBlur = 18; x2.fillStyle = '#fff'; x2.fillText(t, 80, 86); x2.shadowBlur = 6; x2.fillText(t, 80, 86);
    glyphs.set(key, cv2); return cv2;
  }
  // one holographic docking slot: glass slab with lit sides, a glowing rim, corner beacons and a floating number
  function slab(out, pts, hgt, pal, T, hi, label, angle, cs) {
    let cx = 0, cz = 0; pts.forEach(q => { cx += q[0]; cz += q[1]; }); cx /= pts.length; cz /= pts.length;
    const P = pts.map(q => [cx + (q[0] - cx) * .94, cz + (q[1] - cz) * .94]), pul = hi ? .5 + .5 * Math.sin(T * 4) : 0;
    const top = pal.top.map((v, i) => i < 3 ? Math.min(1, v + (hi ? .18 + .12 * pul : 0) * (i === 1 ? 1 : .6)) : v), rim = hi ? [.75, 1, .85, 1] : pal.rim;
    // top face (holo grid)
    const t = earclip(P); for (let i = 0; i < t.length; i += 3) for (let k = 0; k < 3; k++) { const q = P[t[i + k]]; pv(out.top, q[0], hgt, q[1], q[0] / 14, q[1] / 14, 0, 0, top); }
    // sides, lit from the north-west
    for (let i = 0; i < P.length; i++) {
      const a = P[i], b = P[(i + 1) % P.length], dx = b[0] - a[0], dz = b[1] - a[1], l = Math.hypot(dx, dz) || 1; let nx = dz / l, nz = -dx / l;
      if (nx * ((a[0] + b[0]) / 2 - cx) + nz * ((a[1] + b[1]) / 2 - cz) < 0) { nx = -nx; nz = -nz; }
      const sh = .55 + .45 * Math.max(0, nx * -.6 + nz * -.8), c1 = [pal.side[0] * sh, pal.side[1] * sh, pal.side[2] * sh, .9], c0 = [.01, .04, .08, .9];
      [[a, 0, c0], [b, 0, c0], [b, 1, c1], [a, 0, c0], [b, 1, c1], [a, 1, c1]].forEach(([q, up, c]) => pv(out.side, q[0], up ? hgt : 0, q[1], 0, 0, 0, 0, c));
    }
    ribbon(out.rim, P, true, 1.9, hgt + .3, rim);
    // corner beacons
    P.forEach(q => { quad(out.beam, [[q[0] - rgt[0] * .9, hgt + 15, q[1] - rgt[2] * .9], [q[0] + rgt[0] * .9, hgt + 15, q[1] + rgt[2] * .9], [q[0] + rgt[0] * .9, hgt, q[1] + rgt[2] * .9], [q[0] - rgt[0] * .9, hgt, q[1] - rgt[2] * .9]], [0, 0, 1, 1], [rim[0], rim[1], rim[2], .55]); out.glow.push(q); });
    if (label) { const sz = Math.min(cs * .78, 46), key = label + '|' + pal.gc; flatQuad(out.num[key] = out.num[key] || [], cx, cz, sz, sz, angle, hgt + .8, [0, 0, 1, 1], WHITE); }
  }
  const PAL = { box: { top: [.03, .11, .19, .84], rim: [.35, .85, 1, .95], side: [.25, .7, .9], glow: [.4, .9, 1], gc: '#59d5ff' }, fly: { top: [.13, .08, .03, .66], rim: [1, .72, .28, .95], side: [.95, .6, .22], glow: [1, .75, .35], gc: '#ffb347' } };
  function drawBoxes(T) {
    if (!ERASED) eraseSheets();
    const out = { top: [], side: [], rim: [], beam: [], glow: [], num: {} }, hi = new Set(typeof targets !== 'undefined' && targets ? targets.map(m => m.dest) : []);
    boxPolys().forEach(B => {
      const pod = LAY.pods[B.k]; if (!pod) return;
      const pts = B.pts.map(q => { const r = LAY.toL(q[0], q[1], pod); return [r[0], r[1]]; });
      let cs = 1e9; { let x0 = 1e9, x1 = -1e9, z0 = 1e9, z1 = -1e9; pts.forEach(q => { x0 = Math.min(x0, q[0]); x1 = Math.max(x1, q[0]); z0 = Math.min(z0, q[1]); z1 = Math.max(z1, q[1]); }); cs = Math.min(x1 - x0, z1 - z0); }
      let label = null, ang = 0;
      label = B.fly ? 'FLYBY' : B.n; ang = -C.yaw;
      slab(out, pts, B.fly ? 9 : 7, B.fly ? PAL.fly : PAL.box, T, hi.has(B.id), label, ang, cs);
    });
    flush(pQ, out.top, null, 8); flush(pQ, out.side, null, 1); flush(pQ, out.rim, null, 1); flush(pQ, out.beam, null, 1);
    const list = []; Object.entries(out.num).forEach(([key, a]) => { const [t, col] = key.split('|'); list.push({ tex: texOf(glyph(t, col), false), mode: 0, verts: a }); }); batch(list);
    const g = [], r = 7; out.glow.forEach(q => { const y = 7 + 14, Rr = [rgt[0] * r, rgt[1] * r, rgt[2] * r], U = [cup[0] * r, cup[1] * r, cup[2] * r]; quad(g, [[q[0] - Rr[0] + U[0], y - Rr[1] + U[1], q[1] - Rr[2] + U[2]], [q[0] + Rr[0] + U[0], y + Rr[1] + U[1], q[1] + Rr[2] + U[2]], [q[0] + Rr[0] - U[0], y + Rr[1] - U[1], q[1] + Rr[2] - U[2]], [q[0] - Rr[0] - U[0], y - Rr[1] - U[1], q[1] - Rr[2] - U[2]]], [0, 0, 1, 1], [.5, .9, 1, .8]); }); flush(pQ, g, null, 3);
  }
  function ensure() {
    if (LAY || typeof GEO === 'undefined' || typeof SHL === 'undefined') return;
    const S0 = typeof FX !== 'undefined' && FX.sun, m = S0 && GEO.maps[S0.map];
    LAY = SHL.build(GEO, D, m ? [m[0] + S0.cx * .4, m[1] + S0.cy * .4] : null);
    // belts: particle rings (gaps cut out where a pod sits on the ring)
    const r = mulb(4242); belts = [];
    LAY.belts.forEach(b => {
      const pod = LAY.pods[b.k], rc = pod && pod.rect, pts = [];
      for (let i = 0; i < b.n; i++) {
        const g = (r() + r() + r()) / 3, rad = b.r0 + (b.r1 - b.r0) * g, an = r() * 6.2832, x = Math.cos(an) * rad, z = Math.sin(an) * rad;
        if (rc && x > rc[0] - 60 && x < rc[2] + 60 && z > rc[1] - 60 && z < rc[3] + 60) continue;
        const sh = .55 + r() * .45, big = r() < .06;
        pts.push(x, (r() - .5) * (b.r1 - b.r0) * .08, z, 0, 0, 0, 0, b.col[0] * sh, b.col[1] * sh, b.col[2] * sh, big ? .95 : .7 * sh + .2);
      }
      belts.push({ pts: new Float32Array(pts), big: 0 });
    });
    // sky: stars on a distant shell all around, constellation-style lines left out on purpose
    const sp = []; for (let i = 0; i < 3200; i++) { const u = r() * 2 - 1, a = r() * 6.2832, s = Math.sqrt(1 - u * u), R = 52000 + r() * 8000, h = r(); sp.push(Math.cos(a) * s * R, u * R, Math.sin(a) * s * R, 0, 0, 0, 0, h < .12 ? .7 : 1, h < .12 ? .8 : (h > .88 ? .75 : 1), h < .12 ? 1 : (h > .88 ? .6 : 1), .3 + r() * .7); }
    sky = new Float32Array(sp);
  }
  const mapP = (x, y, pod) => LAY.toL(x, y, pod);       // sheet coords -> scene coords (and the pod)
  const pxw = d => 2 * d * Math.tan(FOV / 2) / H; // world units per css pixel at distance d
  function labelOf(txt) {
    let c = labelTex.get(txt); if (c) return c;
    const cv2 = document.createElement('canvas'), x2 = cv2.getContext('2d'), fs = 40; x2.font = `600 ${fs}px "IBM Plex Sans Condensed","Arial Narrow",sans-serif`;
    const w = Math.ceil(x2.measureText(txt).width) + 16; cv2.width = w; cv2.height = 56; x2.font = `600 ${fs}px "IBM Plex Sans Condensed","Arial Narrow",sans-serif`; x2.textAlign = 'center'; x2.textBaseline = 'middle';
    x2.lineWidth = 7; x2.lineJoin = 'round'; x2.strokeStyle = 'rgba(2,6,14,.9)'; x2.strokeText(txt, w / 2, 29); x2.fillStyle = '#bfe9f5'; x2.fillText(txt, w / 2, 29);
    c = { cv: cv2, w, h: 56 }; labelTex.set(txt, c); return c;
  }
  function frame() {
    if (!ready || !V.on) return;
    ensure(); if (!LAY) return;
    const S = LAY.S, T = (typeof FX !== 'undefined' && FX.t) || 0;
    setupCam();
    gl.viewport(0, 0, cvs.width, cvs.height); gl.clearColor(.008, .014, .03, 1); gl.clear(gl.COLOR_BUFFER_BIT);
    const dist2 = (x, y, z) => (x - eye[0]) ** 2 + (y - eye[1]) ** 2 + (z - eye[2]) ** 2;
    const px = pxw(C.dist);
    // 1 sky
    gl.useProgram(pQ); gl.uniformMatrix4fv(pQ.u.M, false, vp); gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, sky, gl.DYNAMIC_DRAW); gl.uniform1i(pQ.u.MODE, 4); gl.uniform1f(pQ.u.PT, 2.4 * dpr); gl.drawArrays(gl.POINTS, 0, sky.length / 11);
    if (typeof FX !== 'undefined' && FX.neb) { const a = [], Sz = 200000, rep = Sz / 9000; flatQuad(a, 0, 0, Sz, Sz, 0, -9000, [0, 0, rep, rep], [1, 1, 1, .55]); flush(pQ, a, texOf(FX.neb, false, true), 0); }
    // 2 belts, orbit rings, spokes
    {
      belts.forEach((b, i) => { gl.useProgram(pQ); gl.uniformMatrix4fv(pQ.u.M, false, vp); gl.bindBuffer(gl.ARRAY_BUFFER, vbo); gl.bufferData(gl.ARRAY_BUFFER, b.pts, gl.DYNAMIC_DRAW); gl.uniform1i(pQ.u.MODE, 4); gl.uniform1f(pQ.u.PT, Math.max(1.8, Math.min(7, 9000 / Math.max(900, C.dist))) * dpr); gl.drawArrays(gl.POINTS, 0, b.pts.length / 11); });
      const a = [], rw = Math.max(9, px * 1.5);
      LAY.rings.concat([{ r: LAY.pods.sca.ring }]).forEach(rg => ribbon(a, circlePts(0, 0, rg.r, 160), true, rw, 1, [.31, .76, .85, .3]));
      for (let k = 0; k < 12; k++) { const an = k / 12 * 6.2832; ribbon(a, [[Math.cos(an) * 700, Math.sin(an) * 700], [Math.cos(an) * 19000, Math.sin(an) * 19000]], false, rw * .55, .5, [.31, .76, .85, .08]); }
      flush(pQ, a, null, 1);
    }
    // 3 pod art: the printed sheets, cut to each system and faded at the edges
    const L1 = [], L2 = [];
    Object.values(LAY.pods).forEach(p => {
      const bw = p.bbox[2] - p.bbox[0], bh = p.bbox[3] - p.bbox[1];
      p.arts.forEach(art => {
        const img = (ERASED && ERASED[art.sheet]) || IMG.maps[art.sheet]; if (!img) return;
        const [x0, y0, x1, y1] = art.rect, A = mapP(x0, y0, p), B = mapP(x1, y1, p), sh = GEO.maps[art.sheet];
        const u0 = (x0 - sh[0]) / sh[2], u1 = (x1 - sh[0]) / sh[2], v0 = (y0 - sh[1]) / sh[3], v1 = (y1 - sh[1]) / sh[3];
        const q0 = [(x0 - p.bbox[0]) / bw, (y0 - p.bbox[1]) / bh], q1 = [(x1 - p.bbox[0]) / bw, (y1 - p.bbox[1]) / bh], a = [];
        const Pt = [[A[0], 0, A[1]], [B[0], 0, A[1]], [B[0], 0, B[1]], [A[0], 0, B[1]]], UV = [[u0, v0], [u1, v0], [u1, v1], [u0, v1]], QQ = [[q0[0], q0[1]], [q1[0], q0[1]], [q1[0], q1[1]], [q0[0], q1[1]]];
        [0, 1, 2, 0, 2, 3].forEach(i => pv(a, Pt[i][0], 0, Pt[i][2], UV[i][0], UV[i][1], QQ[i][0], QQ[i][1], WHITE));
        L1.push({ tex: texOf(img, true), mode: 6, verts: a });
        if (ovInfo) { const o = ovInfo, K = o.k, b = [], t = texOf(o.c, false); if (o.dirty) { reupload(o.c); o.dirty = false; } const ow = o.c.width, oh = o.c.height, UV2 = [[x0 * K / ow, y0 * K / oh], [x1 * K / ow, y0 * K / oh], [x1 * K / ow, y1 * K / oh], [x0 * K / ow, y1 * K / oh]]; [0, 1, 2, 0, 2, 3].forEach(i => pv(b, Pt[i][0], 1.2, Pt[i][2], UV2[i][0], UV2[i][1], 0, 0, WHITE)); L2.push({ tex: t, mode: 0, verts: b }); }
      });
    });
    batch(L1); batch(L2);
    if (C.dist < 26000) drawBoxes(T);
    { const a = []; Object.values(LAY.pods).forEach(p => { const r = p.rect, i = 14; ribbon(a, [[r[0] + i, r[1] + i], [r[2] - i, r[1] + i], [r[2] - i, r[3] - i], [r[0] + i, r[3] - i]], true, Math.max(5, px * 1.2), .6, [.31, .76, .85, .22]); }); flush(pQ, a, null, 1); }
    // 4 the Sun
    {
      const R = LAY.sunR, y = R * .35, a = [], g = [];
      const bq = (arr, rr, mode, c) => { const Rr = [rgt[0] * rr, rgt[1] * rr, rgt[2] * rr], U = [cup[0] * rr, cup[1] * rr, cup[2] * rr]; quad(arr, [[-Rr[0] + U[0], y - Rr[1] + U[1], -Rr[2] + U[2]], [Rr[0] + U[0], y + Rr[1] + U[1], Rr[2] + U[2]], [Rr[0] - U[0], y + Rr[1] - U[1], Rr[2] - U[2]], [-Rr[0] - U[0], y - Rr[1] - U[1], -Rr[2] - U[2]]], [0, 0, 1, 1], c); };
      bq(g, R * 3.4, 3, [1, .62, .2, .85]); flush(pQ, g, null, 3);
      bq(a, R, 7, WHITE); flush(pQ, a, null, 7);
      const c = proj(0, y, 0), e = proj(rgt[0] * R, y + rgt[1] * R, rgt[2] * R); picks = []; if (c && e) picks.push({ sx: c[0], sy: c[1], pr: Math.hypot(e[0] - c[0], e[1] - c[1]), hit: { t: 'world', k: 'sun' }, z: c[2], planet: true });
    }
    // 5 ground decorations: orbit dots, selections, drag targets
    {
      const a = [], fill = [], dots = [], sc = pt => { const q = mapP(pt[0], pt[1]); return [q[0], q[1]]; };
      // a whole shape moves with one pod: pick the pod from the shape's middle
      const mapShape = pts => { let cx = 0, cy = 0; pts.forEach(p => { cx += p[0]; cy += p[1]; }); const pod = LAY.podAt(cx / pts.length, cy / pts.length); return pts.map(p => { const q = mapP(p[0], p[1], pod); return [q[0], q[1]]; }); };
      if (G) Object.keys(GEO.worlds).forEach(w => {
        if (!G.w[w] || !GEO.worlds[w].poly || !DOTR[w]) return;
        const R = ringOf(w), n = Math.round(2 * Math.PI * R.r / 9), rp = LAY.podAt(R.c[0], R.c[1]);
        for (let i = 0; i < n; i++) { const an = i / n * 2 * Math.PI, q = mapP(R.c[0] + Math.cos(an) * R.r, R.c[1] + Math.sin(an) * R.r, rp); flatQuad(dots, q[0], q[1], 5 * S * 1.5, 5 * S * 1.5, 0, 2, [0, 0, 1, 1], [.59, .52, .84, .9]); }
      });
      gfx.forEach(g => {
        const c = parse(g.color);
        if (g.k === 'ring') { const q = mapP(g.x, g.y); ribbon(a, circlePts(q[0], q[1], g.r * S, 40), true, g.w * 1.4 * S, 3, c); }
        else if (g.k === 'poly') { const pts = mapShape(g.pts); if (g.fill) fillPoly(fill, pts, 2.5, parse(g.fill)); ribbon(a, pts, true, g.w * 1.4 * S, 3, c); }
      });
      if (typeof targets !== 'undefined' && targets) {
        const seen = new Set(), dests = new Set(targets.map(m => m.dest));
        targets.forEach(m => {
          if (seen.has(m.dest)) return; seen.add(m.dest);
          const p = E.P(m.dest), z = zoneShape(m.dest, p.t === 'orbit' && dests.has('surf:' + p.w)), raw = z.poly ? z.poly : circlePts(z.c[0], z.c[1], z.r, 36), pts = mapShape(raw);
          fillPoly(fill, pts, 2.6, [.31, .76, .85, .2]); ribbon(a, pts, true, 7 * S, 3.2, [.31, .76, .85, .95]); if (z.hole) ribbon(a, mapShape(z.hole), true, 5 * S, 3.2, [.31, .76, .85, .8]);
        });
      }
      flush(pQ, dots, null, 2); flush(pQ, fill, null, 1); flush(pQ, a, null, 1);
    }
    // 6 flat sprites (world cards, base counters, trade markers)
    const flat = [], stand = [];
    rec.forEach(r => { const q = mapP(r.x, r.y); r.X = q[0]; r.Z = q[1]; (r.mode === 'stand' ? stand : flat).push(r); });
    {
      const list = [];
      flat.forEach(r => {
        const a = [], iw = r.img.width, ih = r.img.height, uv = [r.f[0] / iw, r.f[1] / ih, (r.f[0] + r.f[2]) / iw, (r.f[1] + r.f[3]) / ih];
        flatQuad(a, r.X, r.Z, r.w * S, r.h * S, r.a, r.text ? 6 : 4, uv, WHITE); list.push({ tex: texOf(r.img, false), mode: 0, verts: a });
      });
      batch(list);
    }
    // 7 standing items, far to near: planets, counters, labels
    const items = [];
    const B = typeof FX !== 'undefined' && FX.bodies;
    if (B && planetTex && G) Object.entries(B.b).forEach(([k, b]) => {
      const m = GEO.maps[b.map], q = mapP(m[0] + b.cx * .4, m[1] + b.cy * .4), r = b.r * .4 * S, y = r * .55;
      items.push({ t: 'planet', k, b, x: q[0], y, z: q[1], r, d: dist2(q[0], y, q[1]) });
    });
    stand.forEach(r => { const y = (r.lift || 0) * S + r.h * S / 2; items.push({ t: 'spr', r, d: dist2(r.X, y, r.Z) }); });
    items.sort((p, q) => q.d - p.d);
    { const a = []; items.forEach(it => { if (it.t === 'planet') flatQuad(a, it.x, it.z, it.r * 2.1, it.r * 1.2, 0, 1.6, [0, 0, 1, 1], [0, 0, 0, .38]); else if (!it.r.text) flatQuad(a, it.r.X, it.r.Z, it.r.w * S * .9, it.r.w * S * .5, 0, 1.6, [0, 0, 1, 1], [0, 0, 0, .4]); }); flush(pQ, a, null, 2); }
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
        gl.uniform1f(u.row, it.b.row); gl.uniform1f(u.rot, (T * 6.2832 / it.b.spd) % 6.2832);
        const Ld = norm(sub([0, 0, 0], [it.x, 0, it.z])); gl.uniform3f(u.L, dot(Ld, rgt), dot(Ld, cup) * .6 + .25, .55);
        gl.drawArrays(gl.TRIANGLES, 0, 6);
        gl.useProgram(pQ);
        const c = proj(it.x, it.y, it.z), e = proj(it.x + rgt[0] * it.r, it.y + rgt[1] * it.r, it.z + rgt[2] * it.r);
        if (c && e) picks.push({ sx: c[0], sy: c[1], pr: Math.hypot(e[0] - c[0], e[1] - c[1]), hit: { t: 'world', k: it.k }, z: c[2], planet: true });
      } else {
        const r = it.r, iw = r.img.width, ih = r.img.height, uv = [r.f[0] / iw, r.f[1] / ih, (r.f[0] + r.f[2]) / iw, (r.f[1] + r.f[3]) / ih];
        const w = r.w * S, h = r.h * S, hw = w / 2, l = (r.lift || 0) * S, bob = r.text ? 0 : Math.sin(T * 1.3 + r.x * .013 + r.y * .017) * 3 * S;
        const bx = r.X, by = l + bob, bz = r.Z, uh = [cup[0] * h, cup[1] * h, cup[2] * h];
        const P = [[bx - rgt[0] * hw + uh[0], by + uh[1], bz - rgt[2] * hw + uh[2]], [bx + rgt[0] * hw + uh[0], by + uh[1], bz + rgt[2] * hw + uh[2]], [bx + rgt[0] * hw, by, bz + rgt[2] * hw], [bx - rgt[0] * hw, by, bz - rgt[2] * hw]];
        const a = []; quad(a, P, uv, WHITE); run.push({ tex: texOf(r.img, false), mode: 0, verts: a });
        if (!r.text) {
          const c = proj(bx + cup[0] * h / 2, by + cup[1] * h / 2, bz + cup[2] * h / 2), e = proj(bx + rgt[0] * hw + cup[0] * h / 2, by + cup[1] * h / 2, bz + rgt[2] * hw + cup[2] * h / 2);
          if (c && e) picks.push({ sx: c[0], sy: c[1], pr: Math.hypot(e[0] - c[0], e[1] - c[1]), x: r.x, y: r.y, z: c[2], rec: r });
        }
      }
    });
    flushRun();
    // 8 labels for every system, constant size on screen, fading out when you are close
    {
      const a = [], d0 = [];
      const lab = (name, x, z, key, big) => {
        const dd = Math.sqrt(dist2(x, 0, z)), pod = key && LAY.pods[key], ext = pod ? Math.max(pod.rect[2] - pod.rect[0], pod.rect[3] - pod.rect[1]) : 600;
        const al = Math.max(0, Math.min(1, (dd - ext * .9) / (ext * .9)));
        if (al <= 0) return;
        const c = labelOf(name), ph = pxw(dd), h = (big ? 22 : 17) * ph, w = h * c.w / c.h, y = 10 * ph + 6 * ph;
        const Pq = [[x - rgt[0] * w / 2 + cup[0] * h, y + cup[1] * h, z - rgt[2] * w / 2 + cup[2] * h], [x + rgt[0] * w / 2 + cup[0] * h, y + cup[1] * h, z + rgt[2] * w / 2 + cup[2] * h], [x + rgt[0] * w / 2, y, z + rgt[2] * w / 2], [x - rgt[0] * w / 2, y, z - rgt[2] * w / 2]];
        const v = []; quad(v, Pq, [0, 0, 1, 1], [1, 1, 1, al]); d0.push({ tex: texOf(c.cv, false), mode: 0, verts: v });
        flatQuad(a, x, z, 9 * ph, 9 * ph, 0, 3, [0, 0, 1, 1], [.55, .9, 1, al]);
        const s0 = proj(x, y + h / 2, z); if (s0 && al > .3) picks.push({ sx: s0[0], sy: s0[1], pr: Math.max(h / ph * .5, w / ph * .5), hit: key ? { t: 'pod', k: key } : null, z: 0, label: true });
      };
      Object.values(LAY.pods).forEach(p => { if (p.k === 'mer') return; const q = mapP(p.hub[0], p.hub[1], p); lab(p.name.toUpperCase(), q[0], q[1], p.k); });
      lab('SUN', 0, 0, 'mer', true);
      batch(d0); flush(pQ, a, null, 2);
    }
  }
  V.frame = frame;

  // match standing sprites to the flat painter's hit list (so a tap selects the same thing as in the flat view)
  V.finish = function (hitsList) {
    rec.forEach(r => { if (r.mode !== 'stand' || r.text) return; r.hit = null; for (let i = hitsList.length - 1; i >= 0; i--) { const h = hitsList[i]; if ((h.t === 'ship' || h.t === 'oship') && Math.abs(h.x - r.x) < 1.5 && Math.abs(h.y - r.y) < 1.5) { r.hit = h; break; } } });
  };
  // a point on the board under a screen position, in the board's own (flat map) coordinates
  V.sheetAt = (sx, sy) => { const g = ground(sx, sy, 0); if (!g || !LAY) return null; const q = LAY.fromL(g.x, g.y); return q ? { x: q[0], y: q[1] } : null; };
  V.pick = function (sx, sy) {
    let best = null;
    for (const p of picks) {
      if (Math.hypot(sx - p.sx, sy - p.sy) > Math.max(p.pr, 9)) continue;
      const hit = p.planet || p.label ? p.hit : (p.rec && p.rec.hit);
      if (!hit) continue;
      const tier = p.label ? 2 : p.planet ? 1 : 0;   // counters first, then worlds, then system labels
      if (!best || tier < best.tier || (tier === best.tier && p.z < best.z)) best = { z: p.z, hit, tier };
    }
    if (best) return { hit: best.hit, p: null };
    const g = V.sheetAt(sx, sy);
    return { hit: g && typeof hitAtWorld === 'function' ? hitAtWorld(g) : null, p: g };
  };
  V.ground = (sx, sy, h) => ground(sx, sy, h);

  // ---------- camera control ----------
  const clampCam = () => { C.pitch = Math.max(.3, Math.min(1.35, C.pitch)); C.dist = Math.max(120, Math.min(60000, C.dist)); C.tx = Math.max(-22000, Math.min(22000, C.tx)); C.tz = Math.max(-22000, Math.min(22000, C.tz)); };
  const dirtyIt = () => { if (typeof dirty !== 'undefined') dirty = true; };
  V.zoom = f => { C.dist /= f; clampCam(); dirtyIt(); };
  V.rotate = (dy, dp) => { C.yaw += dy; C.pitch += dp; clampCam(); dirtyIt(); };
  const sheetToScene = p => { ensure(); if (!LAY) return [0, 0]; const q = LAY.toL(p[0], p[1]); return [q[0], q[1]]; };
  V.focus = (p, s) => { const q = sheetToScene(p); C.tx = q[0]; C.tz = q[1]; if (s) C.dist = Math.max(250, 900 / Math.max(.3, s)); clampCam(); dirtyIt(); };
  V.focusPod = k => { ensure(); const p = LAY && LAY.pods[k]; if (!p) return; const r = p.rect; C.tx = (r[0] + r[2]) / 2; C.tz = (r[1] + r[3]) / 2; C.dist = Math.max(r[2] - r[0], r[3] - r[1]) * 1.35; C.pitch = Math.max(C.pitch, .9); clampCam(); dirtyIt(); };
  V.fit = () => { C.tx = 0; C.tz = 400; C.dist = 40000; C.yaw = 0; C.pitch = 1.0; clampCam(); dirtyIt(); };
  V.home = p => { const q = sheetToScene(p); C.tx = q[0]; C.tz = q[1] + 60; C.dist = 1500; C.pitch = .98; C.yaw = 0; clampCam(); dirtyIt(); };
  V.cam = C;
  V.panBy = (p0, sx, sy) => { const p1 = ground(sx, sy, 0); if (!p1 || !p0) return; C.tx += p0.x - p1.x; C.tz += p0.y - p1.y; clampCam(); dirtyIt(); };
  V.picks = () => picks;
  V.toScreen = (x, y, z) => { ensure(); const q = LAY.toL(x, y); return proj(q[0], z || 0, q[1]); };
  V.layout = () => LAY;
  V.canvas = () => cvs;
  V.show = on => { if (cvs) cvs.style.display = on ? 'block' : 'none'; };
})();
