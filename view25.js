/* Stellar Horizons 2.5D view: a dependency-free WebGL2 renderer.
   It draws the same game state as the flat map (positions come from the flat painter's draw calls), with a tilted
   perspective camera, a starfield, spinning planets, hovering counters and flat world cards.
   Public API: V25.on, V25.toggle(), V25.frame(), V25.sprite/text/ring/poly/box (called by the flat painter), V25.pick, ... */
(function () {
  'use strict';
  const V = window.V25 = { on: false, ok: null, mode: 'flat', lift: 0 };
  let gl, cvs, pQ, pP, pR, vbo, W = 1, H = 1, dpr = 1, ready = false;
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
        gl_FragColor=vec4(c*vc.rgb,smoothstep(1.,.97,d));}
      else if(MODE==10){float g=max(step(.988,fract(vuv.x)),step(.988,fract(vuv.y)))*.7;float f=smoothstep(0.,.025,min(min(vq.x,1.-vq.x),min(vq.y,1.-vq.y)));gl_FragColor=vec4(mix(vc.rgb,vec3(.2,.5,.65),g*.5),vc.a*f);}
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
    const u = {}; ['M', 'PT', 'T', 'MODE', 'TM', 'row', 'rot', 'AW', 'AH', 'TW', 'TH', 'DS', 'L', 'SD', 'C1', 'C2', 'LP', 'ICE', 'EL', 'SC', 'RG', 'TT'].forEach(n => u[n] = gl.getUniformLocation(p, n)); p.u = u; return p;
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
      pQ = prog(VS, FSQ); pP = prog(VS, FSP); pR = prog(VS, FSR);
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
  let LAY = null, belts = null, sky = null, labelTex = new Map();
  // the printed transfer and flyby boxes are painted out of the sheets; the 3D models below take their place
  // Earth and Mercury print an irregular flyby outline; they get the same slanted long box as Saturn, Venus and the rest
  const FLYQ = { ear: [[2921, 428], [3043, 428], [2875, 754], [2807, 616]], mer: [[622, 1032], [744, 1032], [576, 1358], [508, 1220]] };
  const boxPolys = () => { const out = []; Object.entries(GEO.sys).forEach(([k, sy]) => { Object.entries(sy.boxPoly).forEach(([n, q]) => out.push({ k, n, id: 'box:' + k + ':' + n, pts: q, fly: false })); out.push({ k, n: 'fly', id: 'fly:' + k, pts: FLYQ[k] || hull(sy.flybyPoly), fly: true }); }); return out; };
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
  // ---------- regular box shapes: squares for the numbered transfer boxes, the flyby box keeps its printed outline ----------
  let BOXSH = {};
  const polyArea = p => Math.abs(p.reduce((a, q, i) => { const r = p[(i + 1) % p.length]; return a + q[0] * r[1] - r[0] * q[1]; }, 0) / 2);
  const cen2 = p => [p.reduce((a, q) => a + q[0], 0) / p.length, p.reduce((a, q) => a + q[1], 0) / p.length];
  function orientedRect(pts) {      // smallest rectangle round a polygon: centre, long-axis direction, length, width
    let best = null;
    for (let i = 0; i < pts.length; i++) {
      const a = pts[i], b = pts[(i + 1) % pts.length], th = Math.atan2(b[1] - a[1], b[0] - a[0]), c = Math.cos(-th), s = Math.sin(-th);
      let u0 = 1e9, u1 = -1e9, v0 = 1e9, v1 = -1e9;
      pts.forEach(p => { const u = p[0] * c - p[1] * s, v = p[0] * s + p[1] * c; u0 = Math.min(u0, u); u1 = Math.max(u1, u); v0 = Math.min(v0, v); v1 = Math.max(v1, v); });
      const ar = (u1 - u0) * (v1 - v0); if (!best || ar < best.ar) best = { ar, th, u0, u1, v0, v1 };
    }
    const cu = (best.u0 + best.u1) / 2, cv = (best.v0 + best.v1) / 2, c = Math.cos(best.th), s = Math.sin(best.th);
    let L = best.u1 - best.u0, Wd = best.v1 - best.v0, th = best.th; if (Wd > L) { const t = L; L = Wd; Wd = t; th += Math.PI / 2; }
    const cc = [cu * c - cv * s, cu * s + cv * c]; return { c: cc, th, L, W: Wd };
  }
  let BOXL = null;
  function computeBoxes() {
    if (BOXL) return BOXL;
    const list = [];
    boxPolys().forEach(B => {
      const pod = LAY.pods[B.k]; if (!pod) return;
      const pts = B.pts.map(q => { const r = LAY.toL(q[0], q[1], pod); return [r[0], r[1]]; });
      list.push({ B, pod, pts, c: cen2(pts), s: Math.sqrt(polyArea(pts)) });
    });
    BOXSH = {};
    list.forEach(it => {
      const { B, pod, pts, c } = it, hub = pod.org, toHub = Math.atan2(hub[1] - c[1], hub[0] - c[0]);
      let shape, cs;
      if (!B.fly) {
        let nd = 1e9; list.forEach(o => { if (o !== it && o.B.k === B.k && !o.B.fly) nd = Math.min(nd, Math.hypot(o.c[0] - c[0], o.c[1] - c[1])); });
        const side = Math.min(it.s * .92, nd * .86), h = side / 2, ca = Math.cos(toHub), sa = Math.sin(toHub);
        shape = [[-h, -h], [h, -h], [h, h], [-h, h]].map(([u, v]) => [c[0] + u * ca - v * sa, c[1] + u * sa + v * ca]); cs = side;
      } else { shape = pts; cs = it.s; }   // the flyby box keeps its printed outline
      BOXSH[B.id] = shape; it.shape = shape; it.cs = cs;
    });
    return BOXL = list;
  }
  function drawBoxes(T) {
    const out = { top: [], side: [], rim: [], beam: [], glow: [], num: {} }, hi = new Set(typeof targets !== 'undefined' && targets ? targets.map(m => m.dest) : []);
    computeBoxes().forEach(({ B, shape, cs }) => slab(out, shape, B.fly ? 9 : 7, B.fly ? PAL.fly : PAL.box, T, hi.has(B.id), B.fly ? 'FLYBY' : B.n, -C.yaw, cs));
    flush(pQ, out.top, null, 8); flush(pQ, out.side, null, 1); flush(pQ, out.rim, null, 1); flush(pQ, out.beam, null, 1);
    const lst = []; Object.entries(out.num).forEach(([key, a]) => { const [t, col] = key.split('|'); lst.push({ tex: texOf(glyph(t, col), false), mode: 0, verts: a }); }); batch(lst);
    const g = [], r = 7; out.glow.forEach(q => { const y = 7 + 14, Rr = [rgt[0] * r, rgt[1] * r, rgt[2] * r], U = [cup[0] * r, cup[1] * r, cup[2] * r]; quad(g, [[q[0] - Rr[0] + U[0], y - Rr[1] + U[1], q[1] - Rr[2] + U[2]], [q[0] + Rr[0] + U[0], y + Rr[1] + U[1], q[1] + Rr[2] + U[2]], [q[0] + Rr[0] - U[0], y + Rr[1] - U[1], q[1] + Rr[2] - U[2]], [q[0] - Rr[0] - U[0], y - Rr[1] - U[1], q[1] - Rr[2] - U[2]]], [0, 0, 1, 1], [.4, .9, 1, .5]); }); if (g.length) flush(pQ, g, null, 3);
  }
  // which box (if any) a screen position is on, among the given destinations: uses the 3D shapes, not the printed polygons
  // frame for the paint code: where a world's base slots are, in board (sheet) coordinates
  V.worldFrame = k => { ensure(); const A = ASM && ASM[k]; if (!A || !asmKind(k).base) return null; const cc = A.toSheet(A.x0 + SLOT.card[0], A.z0 + SLOT.card[1]), CW = SLOT.card[2] / LAY.S; return { a: 0, abs: true, noCard: true, CW, CH: CW * 127 / 192, at: (u, v) => [u, v], slots: A.slots, card: cc }; };
  V.asm = () => ASM;
  V.destAt = function (sx, sy, dests) {
    const g = ground(sx, sy, 0); if (!g) return null;
    const inP = (p, poly) => { let c = false; for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) { const a = poly[i], b = poly[j]; if (((a[1] > p.y) !== (b[1] > p.y)) && p.x < (b[0] - a[0]) * (p.y - a[1]) / (b[1] - a[1]) + a[0]) c = !c; } return c; };
    for (const d of dests) { const sh = BOXSH[d]; if (sh && inP(g, sh)) return d; }
    return null;
  };
  // ---------- digital world boxes: zones, lanes and information plates replace the printed world boxes ----------
  const FIELD = { Phy: ['#5aaaff', 'PHYSICS'], Eng: ['#d5dbe6', 'ENGINEERING'], Bio: ['#6edc8c', 'BIOLOGY'] }, RESC = { ORE: '#d9955a', SUP: '#6fc0ee', FUEL: '#f2b13c' };
  const TAGTXT = { severeAtm: 'Severe atmosphere', volcanic: 'Volcanic', rad: 'Radiation', minimal: 'Minimal gravity', reentry: 'Re-entry', venus: null };
  const KIND = w => { const t = w.tags; return t.includes('sunobs') ? 'Solar observatory' : t.includes('alpha') ? 'Interstellar target' : t.includes('tele') ? 'Telescope site' : t.includes('gas') ? 'Gas giant' : t.includes('earth') ? 'Home orbit' : t.includes('rocky') && t.includes('icy') ? 'Rocky-icy world' : t.includes('icy') ? 'Icy world' : t.includes('rocky') ? 'Rocky world' : t.includes('station') ? 'Orbital site' : 'World'; };
  const panels = new Map();
  // set a font that makes the text fit the given width (shrinks in 1px steps down to min) and return the size used
  function fitFont(x, t, weight, size, maxW, min, FONT) { let f = size; x.font = `${weight} ${f}px ${FONT}`; while (x.measureText(t).width > maxW && f > min) { f -= 1; x.font = `${weight} ${f}px ${FONT}`; } return f; }
  function rrect(x, a, b, w, h, r) { x.beginPath(); x.moveTo(a + r, b); x.arcTo(a + w, b, a + w, b + h, r); x.arcTo(a + w, b + h, a, b + h, r); x.arcTo(a, b + h, a, b, r); x.arcTo(a, b, a + w, b, r); x.closePath(); }
  // number of bases (any faction, plus a non-player faction's) on a world: the tray shows one slot for each, appearing as bases are built
  const baseCount = (k, ws) => (G ? G.bases.filter(b => b.w === k).length : 0) + (typeof otherFacs === 'function' ? otherFacs().reduce((a, g) => a + g.bases.filter(b => b.w === k).length, 0) : 0) + (ws.npf ? 1 : 0);
  function panelFor(k, ws) {
    const w = D.W[k], nb = baseCount(k, ws), key = [ws.v, ws.life, ws.sol, ws.terra, ws.npf, ws.blk, ws.card, nb].join('|'); let P = panels.get(k);
    if (P && P.key === key) return P;
    if (!P) { const cv2 = document.createElement('canvas'); const sz = asmSize(k); cv2.width = Math.round(sz[0] * K25); cv2.height = Math.round(sz[1] * K25); P = { cv: cv2 }; panels.set(k, P); }
    P.key = key; const x = P.cv.getContext('2d'), F = w.tags.includes('alpha') ? ['#e8d27a', 'VARIABLE FIELD'] : FIELD[w.f] || ['#9ad', ''], fc = F[0], dead = ws.v < 1, FONT = '"IBM Plex Sans Condensed","Arial Narrow",sans-serif';
    x.setTransform(1, 0, 0, 1, 0, 0); x.clearRect(0, 0, P.cv.width, P.cv.height); x.setTransform(PWS * K25 / 640, 0, 0, PWS * K25 / 640, 0, 0);
    rrect(x, 6, 6, 628, 340, 24); x.fillStyle = 'rgba(4,12,26,.86)'; x.fill(); x.lineWidth = 4; x.strokeStyle = fc; x.globalAlpha = .85; x.stroke(); x.globalAlpha = 1;
    x.fillStyle = fc; x.globalAlpha = .18; rrect(x, 6, 6, 628, 56, 24); x.fill(); x.globalAlpha = 1;
    x.textBaseline = 'middle';
    // name and kind
    x.font = `700 24px ${FONT}`; const chipW = x.measureText(F[1]).width;
    fitFont(x, w.n, 700, 56, 588 - 28 - chipW - 24, 20, FONT);
    x.textAlign = 'left'; x.fillStyle = '#eaf6ff'; x.fillText(w.n, 28, 36);
    fitFont(x, KIND(w), 500, 28, 560, 14, FONT); x.fillStyle = '#9fb7cc'; x.fillText(KIND(w), 28, 86);
    // field chip
    x.font = `700 24px ${FONT}`; x.textAlign = 'right'; x.fillStyle = fc; x.fillText(F[1], 616, 36);
    // explore tile
    x.save(); x.translate(100, 200);
    x.beginPath(); for (let i = 0; i < 6; i++) { const a = i / 6 * 6.2832 + .5236; x.lineTo(Math.cos(a) * 82, Math.sin(a) * 82); } x.closePath();
    x.fillStyle = dead ? 'rgba(60,20,20,.8)' : 'rgba(255,255,255,.07)'; x.fill(); x.lineWidth = 5; x.strokeStyle = dead ? '#ef6b5b' : fc; x.stroke();
    x.textAlign = 'center'; x.font = `700 20px ${FONT}`; x.fillStyle = '#a9bfd2'; x.fillText('EXPLORE', 0, -52);
    x.font = `700 104px ${FONT}`; x.shadowColor = dead ? '#ef6b5b' : fc; x.shadowBlur = 22; x.fillStyle = '#fff'; x.fillText(String(Math.max(0, ws.v)), 0, 4); x.shadowBlur = 0;
    x.font = `600 19px ${FONT}`; x.fillStyle = dead ? '#ef6b5b' : '#a9bfd2'; x.fillText(dead ? 'DEPLETED' : ws.v !== w.v ? 'printed ' + w.v : 'research value', 0, 56);
    x.restore();
    // stat boxes
    const stat = (a, label, val, col) => { rrect(x, a, 112, 128, 92, 12); x.fillStyle = 'rgba(255,255,255,.06)'; x.fill(); x.textAlign = 'left'; fitFont(x, label, 600, 19, 104, 11, FONT); x.fillStyle = '#8fa6bb'; x.fillText(label, a + 12, 132); fitFont(x, val, 700, 46, 104, 20, FONT); x.fillStyle = col || '#fff'; x.fillText(val, a + 12, 172); };
    stat(196, 'LIFE CHANCE', ws.life ? 'FOUND' : (w.tags.includes('alpha') ? '3–10%' : w.life ? w.life + '%' : '—'), ws.life ? '#6edc8c' : '#fff');
    stat(334, 'BASE COST', w.base ? String(w.base) : '—');
    rrect(x, 472, 112, 152, 92, 12); x.fillStyle = 'rgba(255,255,255,.06)'; x.fill(); x.textAlign = 'left'; fitFont(x, 'PRODUCES', 600, 19, 128, 11, FONT); x.fillStyle = '#8fa6bb'; x.fillText('PRODUCES', 484, 132);
    const pr = Object.entries(w.prod || {}); if (!pr.length) { x.font = `700 46px ${FONT}`; x.fillStyle = '#fff'; x.fillText('—', 484, 172); }
    pr.forEach(([r, n], i) => { const yy = 156 + i * 24; x.fillStyle = RESC[r] || '#fff'; x.beginPath(); x.arc(492, yy + 8, 7, 0, 6.2832); x.fill(); fitFont(x, `${r} ${n}`, 700, 26, 112, 14, FONT); x.fillStyle = '#fff'; x.fillText(`${r} ${n}`, 506, yy + 9); });
    // tags and state
    const chips = []; w.tags.forEach(t => { if (TAGTXT[t]) chips.push([TAGTXT[t], '#9fc3dd']); });
    if (w.tags.includes('alpha')) { chips.push(['d10 per success:', '#e8d27a'], ['1-4 Physics 3%', '#5aaaff', 1], ['5-7 Engineering 5%', '#d5dbe6'], ['8-10 Biology 10%', '#6edc8c']); }
    if (ws.sol) chips.push(['Solar power', '#f2b13c']); if (D.TERRA && D.TERRA[k]) chips.push([`Terraform ${ws.terra}/${D.TERRA[k]}`, '#6edc8c']);
    if (ws.npf) chips.push([`${(typeof E !== 'undefined' && E.npfName) ? E.npfName(G, k) : 'NPF'} base`, '#c9a6ff']); if (ws.blk) chips.push(['BLOCKADED', '#ef6b5b']);
    {      // chips wrap inside the plate: the font shrinks until every row fits (a chip with a third value breaks the line after it)
      const limit = w.rng ? 314 : 338, W0 = 428; let fz = 25, rows;
      const lay = f => { x.font = `600 ${f}px ${FONT}`; const pad = f * .52, hh = f * 1.5, out = []; let cx = 196, cy = 236, ok = true; chips.forEach(([t, col, br]) => { const wd = x.measureText(t).width + pad * 2; if (wd > W0) ok = false; if (cx + wd > 196 + W0 && cx > 196) { cx = 196; cy += hh + 8; } out.push({ t, col, x: cx, y: cy, wd, hh, pad }); cx += wd + 10; if (br) { cx = 196 + W0 + 1; } }); return { out, ok: ok && (!out.length || out[out.length - 1].y + hh <= limit) }; };
      for (;;) { rows = lay(fz); if (rows.ok || fz <= 13) break; fz -= 1; }
      x.font = `600 ${fz}px ${FONT}`; rows.out.forEach(c => { rrect(x, c.x, c.y, c.wd, c.hh, c.hh / 2); x.fillStyle = 'rgba(255,255,255,.07)'; x.fill(); x.lineWidth = 2; x.strokeStyle = c.col; x.stroke(); x.fillStyle = c.col; x.textAlign = 'left'; x.fillText(c.t, c.x + c.pad, c.y + c.hh / 2 + 1); });
    }
    if (w.rng) { x.textAlign = 'right'; fitFont(x, `random world d100 ${w.rng[0]}–${w.rng[1]}`, 500, 19, 400, 11, FONT); x.fillStyle = '#6f879b'; x.fillText(`random world d100 ${w.rng[0]}–${w.rng[1]}`, 616, 326); }
    if (dead) { x.fillStyle = 'rgba(20,0,0,.28)'; rrect(x, 6, 6, 628, 340, 24); x.fill(); }
    x.setTransform(1, 0, 0, 1, 0, 0); drawTray(x, k, ws, w, FONT, nb); P.dirty = true; return P;
  }
  // ---------- world boxes: one digital assembly per world (info plate, card slot, life slot, base tray), placed once, clear of everything ----------
  const K25 = 1.8, PWS = 260, PHS = 143, TRW = 380, TRH = 251;          // canvas pixels per scene unit; plate and full-assembly size in scene units
  const asmKind = k => { const w = D.W[k], t = w.tags, earth = t.includes('earth'), gas = t.includes('gas'); return { base: !!w.base || gas || earth, card: !earth && (!!w.base || gas) }; };
  const asmSize = k => asmKind(k).base ? [TRW, TRH] : [PWS, PHS];
  const SLOT = { card: [325, 36.5, 110, 73], life: [288, 108], base: i => [8 + 86 * (i % 4) + 22, 176 + 50 * Math.floor(i / 4)] };
  let ASM = null;
  const BONUS = { all: 'all', probe: 'probes', crew: 'crewed', rover: 'rovers', orbiter: 'orbiters', flyby: 'flybys', spec: 'specialists' };
  function segD(p, a, b) { const dx = b[0] - a[0], dz = b[1] - a[1], t = Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / (dx * dx + dz * dz || 1))); return Math.hypot(p[0] - a[0] - dx * t, p[1] - a[1] - dz * t); }
  function polyD(p, poly) {
    let ins = false, d = 1e9; for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) { const a = poly[i], b = poly[j]; if (((a[1] > p[1]) !== (b[1] > p[1])) && p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]) ins = !ins; d = Math.min(d, segD(p, a, b)); }
    return ins ? -d : d;
  }
  const segX = (a, b, c, d) => { const o = (p, q, r) => (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0]); return o(a, b, c) * o(a, b, d) < 0 && o(c, d, a) * o(c, d, b) < 0; };
  function polyRect(poly, r, m) {        // does a polygon touch the rectangle grown by m?
    const R = [r[0] - m, r[1] - m, r[2] + m, r[3] + m], cs = [[R[0], R[1]], [R[2], R[1]], [R[2], R[3]], [R[0], R[3]]];
    if (poly.some(p => p[0] > R[0] && p[0] < R[2] && p[1] > R[1] && p[1] < R[3])) return true;
    if (cs.some(c => polyD(c, poly) < 0)) return true;
    for (let i = 0; i < poly.length; i++) for (let j = 0; j < 4; j++) if (segX(poly[i], poly[(i + 1) % poly.length], cs[j], cs[(j + 1) % 4])) return true;
    return false;
  }
  const rectR = (a, b, m) => a[0] - m < b[2] && a[2] + m > b[0] && a[1] - m < b[3] && a[3] + m > b[1];
  const circR = (r, c, rad) => { const dx = Math.max(r[0] - c[0], 0, c[0] - r[2]), dz = Math.max(r[1] - c[1], 0, c[1] - r[3]); return Math.hypot(dx, dz) < rad; };
  function placeAsm(S) {
    const circ = [], polys = [], B = typeof FX !== 'undefined' && FX.bodies, ks = Object.keys(GEO.worlds).filter(k => D.W[k] && podOfW(k)), ring = {};
    if (B) Object.values(B.b).forEach(b => { const m = GEO.maps[b.map], q = mapP(m[0] + b.cx * .4, m[1] + b.cy * .4); circ.push([q[0], q[1], b.r * .4 * S * 1.5, null]); });
    ks.forEach(k => { const R = ringOf(k), c = mapP(R.c[0], R.c[1], podOfW(k)); ring[k] = { c, r: R.r * S + 18 }; circ.push([c[0], c[1], ring[k].r, k]); });
    computeBoxes().forEach(it => polys.push(it.shape));
    const placed = [], out = {}, order = ks.slice().sort((a, b) => (asmSize(b)[0] * asmSize(b)[1]) - (asmSize(a)[0] * asmSize(a)[1]) || (a < b ? -1 : 1));
    order.forEach(k => {
      const [w, h] = asmSize(k), { c, r } = ring[k], cands = [], g = 12;
      const add = (x0, z0, pref) => cands.push({ x0, z0, pref });
      const anchor = k === 'jup' && ring.tro ? ring.tro : null;      // Jupiter's box sits clear under the Trojans & Greeks
      if (anchor) { for (let ex = 0; ex <= 120; ex += 20) for (let off = -w * .5; off <= w * .5; off += 20) add(anchor.c[0] - w / 2 + off, anchor.c[1] + anchor.r + g + ex, ex * .2 + Math.abs(off) * .05); }
      else if (k === 'eur') { for (let ex = 0; ex <= 160; ex += 10) for (let off = -.5; off <= .5; off += .125) add(c[0] - w / 2 + off * w, c[1] + r + g + ex, ex * 1.2 + Math.abs(off) * 20); }      // Europa's box goes straight below it
      else for (let ex = 0; ex <= 140; ex += 14) {
        for (let off = -.5; off <= .5; off += .125) {
          add(c[0] + r + g + ex, c[1] - h / 2 + off * h, ex * 1.2 + Math.abs(off) * 20);                  // right
          add(c[0] - w / 2 + off * w, c[1] + r + g + ex, 16 + ex * 1.2 + Math.abs(off) * 20);             // below
          add(c[0] - r - g - ex - w, c[1] - h / 2 + off * h, 34 + ex * 1.2 + Math.abs(off) * 20);         // left
          add(c[0] - w / 2 + off * w, c[1] - r - g - ex - h, 52 + ex * 1.2 + Math.abs(off) * 20);         // above
        }
      }
      let best = null;
      cands.forEach(cd => {
        const R = [cd.x0, cd.z0, cd.x0 + w, cd.z0 + h]; let pen = 0;
        circ.forEach(o => { if (circR(R, o, o[2] + 4)) pen += 1000; });
        polys.forEach(pg => { if (polyRect(pg, R, 6)) pen += 1000; });
        placed.forEach(q => { if (rectR(R, q.rect, 8)) pen += 1000; });
        // the tether to the ring must not cross other boxes, rings or boxes
        const nx = Math.max(R[0], Math.min(c[0], R[2])), nz = Math.max(R[1], Math.min(c[1], R[3])), L = Math.hypot(nx - c[0], nz - c[1]);
        for (let t = .2; t < .95 && L > 1; t += .15) {
          const p = [c[0] + (nx - c[0]) * t, c[1] + (nz - c[1]) * t];
          if (circ.some(o => o[3] !== k && Math.hypot(p[0] - o[0], p[1] - o[1]) < o[2]) || polys.some(pg => polyD(p, pg) < 0) || placed.some(q => p[0] > q.rect[0] && p[0] < q.rect[2] && p[1] > q.rect[1] && p[1] < q.rect[3])) pen += 400;
        }
        const sc = pen + cd.pref + L * .3; if (!best || sc < best.sc) best = { sc, cd };
      });
      const cd = best.cd, rect = [cd.x0, cd.z0, cd.x0 + w, cd.z0 + h];
      placed.push({ rect }); out[k] = { k, x0: cd.x0, z0: cd.z0, w, h, rect, c, r, sc: best.sc };
    });
    // the sheet positions of the base slots become anchors of their pod, so counters and bases map to the right pod
    Object.values(out).forEach(A => {
      const pod = podOfW(A.k), toSheet = (X, Z) => [(X - pod.org[0]) / S + pod.hub[0], (Z - pod.org[1]) / S + pod.hub[1]];
      A.toSheet = toSheet; A.slots = [];
      for (let i = 0; i < 8; i++) { const sl = SLOT.base(i), q = toSheet(A.x0 + sl[0], A.z0 + sl[1]); A.slots.push(q); if (i < 4 && LAY.addAnchor) LAY.addAnchor(q[0], q[1], pod.k); }
      // pods grow to hold their world boxes
      const r = pod.rect; r[0] = Math.min(r[0], A.rect[0] - 16); r[1] = Math.min(r[1], A.rect[1] - 16); r[2] = Math.max(r[2], A.rect[2] + 16); r[3] = Math.max(r[3], A.rect[3] + 16);
    });
    return out;
  }
  function drawTray(x, k, ws, w, FONT, nb) {
    const kd = asmKind(k); if (!kd.base) return;
    x.save(); x.scale(K25, K25); x.textBaseline = 'middle';
    const fcol = (FIELD[w.f] || ['#8aa'])[0];
    // base tray: a slot (and a trade-marker pad) appears for each base as it is built, up to seven factions and a non-player faction
    if (nb > 0) {
      const rows = Math.ceil(nb / 4);
      rrect(x, 0, 151, 356, 6 + rows * 50 - 6, 9); x.fillStyle = 'rgba(4,12,26,.82)'; x.fill(); x.lineWidth = 1.4; x.strokeStyle = 'rgba(150,190,230,.35)'; x.stroke();
      x.font = `700 7px ${FONT}`; x.fillStyle = '#7f98ad'; x.textAlign = 'right'; x.fillText('BASES', 351, 158);
      for (let i = 0; i < nb && i < 8; i++) {
        const [cx, cz] = SLOT.base(i);
        x.lineWidth = 1.3; x.strokeStyle = 'rgba(160,200,240,.55)'; rrect(x, cx - 22, cz - 22, 44, 44, 5); x.stroke();
        x.save(); x.setLineDash([2.5, 2.5]); x.lineWidth = 1; x.strokeStyle = 'rgba(160,200,240,.35)'; rrect(x, cx + 26, cz - 15, 30, 30, 4); x.stroke(); x.restore();
        x.font = `600 7px ${FONT}`; x.fillStyle = 'rgba(160,200,240,.35)'; x.textAlign = 'center'; x.fillText('TRADE', cx + 41, cz);
      }
    }
    // life slot
    const noLife = w.tags.includes('earth'), [lx, lz] = SLOT.life, lc = ws.life ? '#6edc8c' : ws.sol ? '#f2b13c' : 'rgba(160,200,240,.4)';
    if (!noLife) {
    x.beginPath(); x.arc(lx, lz, 15, 0, 6.2832); x.fillStyle = 'rgba(4,12,26,.82)'; x.fill(); x.lineWidth = 2; x.strokeStyle = lc; x.stroke();
    x.font = `700 12px ${FONT}`; x.textAlign = 'center'; x.fillStyle = lc; x.fillText(ws.life ? '✓' : ws.sol ? '~' : '?', lx, lz + .5);
    x.textAlign = 'left'; x.font = `600 7px ${FONT}`; x.fillStyle = '#8fa6bb'; x.fillText('LIFE', lx + 21, lz - 6); x.font = `700 9px ${FONT}`; x.fillStyle = ws.life ? '#6edc8c' : ws.sol ? '#f2b13c' : '#9fb7cc'; x.fillText(ws.life ? 'FOUND' : ws.sol ? 'SIGNS' : 'NOT FOUND', lx + 21, lz + 5);
    }
    // card slot
    if (kd.card) {
      const [cx, cz, cw, ch] = SLOT.card, X = cx - cw / 2, Y = cz - ch / 2, c = ws.card && D.CARDS.find(q => q.n === ws.card);
      if (!c) { x.save(); x.setLineDash([4, 3]); x.lineWidth = 1.3; x.strokeStyle = 'rgba(160,200,240,.45)'; rrect(x, X, Y, cw, ch, 8); x.stroke(); x.restore(); x.textAlign = 'center'; fitFont(x, 'WORLD CARD', 700, 9, cw - 14, 5, FONT); x.fillStyle = '#9fb7cc'; x.fillText('WORLD CARD', cx, cz - 6); fitFont(x, 'placed on depletion', 500, 7, cw - 14, 4, FONT); x.fillStyle = '#6f879b'; x.fillText('placed on depletion', cx, cz + 6); }
      else {
        const col = (FIELD[c.rf] || ['#9ad'])[0];
        rrect(x, X, Y, cw, ch, 8); x.fillStyle = 'rgba(4,12,26,.92)'; x.fill(); x.lineWidth = 1.8; x.strokeStyle = col; x.stroke();
        x.fillStyle = col; x.globalAlpha = .2; rrect(x, X, Y, cw, 16, 8); x.fill(); x.globalAlpha = 1;
        let fs = 11; x.font = `700 ${fs}px ${FONT}`; while (x.measureText(c.n).width > 100 && fs > 6) { fs -= .5; x.font = `700 ${fs}px ${FONT}`; }
        x.textAlign = 'left'; x.fillStyle = '#eaf6ff'; x.fillText(c.n, X + 6, Y + 8.5);
        x.save(); x.translate(X + 22, Y + 40); x.beginPath(); for (let i = 0; i < 6; i++) { const a = i / 6 * 6.2832 + .5236; x.lineTo(Math.cos(a) * 16, Math.sin(a) * 16); } x.closePath(); x.fillStyle = 'rgba(255,255,255,.07)'; x.fill(); x.lineWidth = 1.8; x.strokeStyle = col; x.stroke();
        x.textAlign = 'center'; x.font = `700 21px ${FONT}`; x.fillStyle = '#fff'; x.shadowColor = col; x.shadowBlur = 6; x.fillText(String(c.rv), 0, 1); x.shadowBlur = 0; x.font = `600 6px ${FONT}`; x.fillStyle = '#a9bfd2'; x.fillText((FIELD[c.rf] || ['', ''])[1].slice(0, 3), 0, 12); x.restore();
        let yy = Y + 26; x.textAlign = 'left'; Object.entries(c.prod).forEach(([r, n]) => { if (!n) return; x.fillStyle = RESC[r] || '#fff'; x.beginPath(); x.arc(X + 46, yy, 3.2, 0, 6.2832); x.fill(); fitFont(x, `${r} ${n}`, 700, 10, X + cw - 6 - (X + 53), 5, FONT); x.fillStyle = '#fff'; x.fillText(`${r} ${n}`, X + 53, yy + .5); yy += 12; });
        const bt = Object.entries(c.bonus).map(([a, v]) => `+${v} ${BONUS[a] || a}`).concat(c.lifeB ? [`+${c.lifeB}% life`] : []).join(' · ');
        fitFont(x, 'EXPLORE ' + bt, 600, 6.5, cw - 10, 3.5, FONT); x.fillStyle = '#9fc3dd'; x.textAlign = 'left'; x.fillText('EXPLORE ' + bt, X + 6, Y + ch - 5);
      }
    }
    x.restore();
  }
  function drawBeltLinks(T, S, px) {
    if (!G) return; const lanes = [];
    // belt links: the Main Belt, the Kuiper Belt and the Scattered Disk are joined to their satellite worlds by arcs along the belt
    const SATH = { mer: 'sun', cer: 'bel', hyg: 'bel', ves: 'bel', plu: 'kui', hau: 'kui', eri: 'sca', sed: 'sca' }, HUEL = { sun: [1, .72, .3], bel: [.95, .78, .5], kui: [.62, .78, .98], sca: [.75, .65, 1] };
    Object.keys(SATH).forEach(k => {
      const hk = SATH[k], hp = LAY.pods[hk], sp = LAY.pods[k]; if (!hp || !sp || !GEO.worlds[k]) return;
      let A, ra; if (GEO.worlds[hk]) { const R = ringOf(hk); A = mapP(R.c[0], R.c[1], hp); ra = R.r * S + 12; } else { A = mapP(hp.hub[0], hp.hub[1], hp); ra = 80; }
      const R2 = ringOf(k), B = mapP(R2.c[0], R2.c[1], sp), rb = R2.r * S + 12, col = HUEL[hk];
      const r0 = Math.hypot(A[0], A[1]), r1 = Math.hypot(B[0], B[1]); let a0 = Math.atan2(A[1], A[0]), da = Math.atan2(B[1], B[0]) - a0; while (da > Math.PI) da -= 6.2832; while (da < -Math.PI) da += 6.2832;
      const n = Math.max(30, Math.ceil(Math.abs(da) * Math.max(r0, r1) / 90)), pts = [], straight = hk === 'sun';      // the Sun link is a straight line
      for (let i = 0; i <= n; i++) { const t = i / n, rr = r0 + (r1 - r0) * t, an = a0 + da * t, q = straight ? [A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t] : [Math.cos(an) * rr, Math.sin(an) * rr]; if (Math.hypot(q[0] - A[0], q[1] - A[1]) > ra && Math.hypot(q[0] - B[0], q[1] - B[1]) > rb && !(straight && q[0] > sp.rect[0] && q[0] < sp.rect[2] && q[1] > sp.rect[1] && q[1] < sp.rect[3])) pts.push(q); }
      if (pts.length < 2) return;
      ribbon(lanes, pts, false, Math.max(2, px * 1.0), 1.3, [col[0], col[1], col[2], .22]);
      let acc = 0, next = (T * 70) % 150; const ds = Math.max(12, px * 4);
      for (let i = 1; i < pts.length; i++) { const p0 = pts[i - 1], p1 = pts[i], L = Math.hypot(p1[0] - p0[0], p1[1] - p0[1]); while (next < acc + L) { const u = (next - acc) / L; flatQuad(lanes, p0[0] + (p1[0] - p0[0]) * u, p0[1] + (p1[1] - p0[1]) * u, ds, ds, 0, 1.5, [0, 0, 1, 1], [col[0], col[1], col[2], .85]); next += 150; } acc += L; }
      const e = pts[pts.length - 1], f = pts[pts.length - 2], dx = e[0] - f[0], dz = e[1] - f[1], l = Math.hypot(dx, dz) || 1, ux = dx / l, uz = dz / l, h = Math.max(30, px * 9);
      fillPoly(lanes, [[e[0], e[1]], [e[0] - ux * h - uz * h * .45, e[1] - uz * h + ux * h * .45], [e[0] - ux * h + uz * h * .45, e[1] - uz * h - ux * h * .45]], 1.5, [col[0], col[1], col[2], .9]);
    });
    flush(pQ, lanes, null, 1);
  }
  function drawWorlds(T, S, px) {
    if (!G) return;
    const zone = [], rimv = [], dots = [], fillv = [], lanes = [], pl = [];
    const hubOf = sk => { const h = D.SYS[sk] && D.SYS[sk].hub; return h && GEO.worlds[h] ? h : null; };
    Object.keys(GEO.worlds).forEach(k => {
      const ws = G.w[k], gw = GEO.worlds[k], dw = D.W[k]; if (!ws || !dw) return;
      const pod = podOfW(k); if (!pod) return;
      const R = ringOf(k), c = mapP(R.c[0], R.c[1], pod), r = R.r * S, fc = parse((FIELD[dw.f] || ['#8aa'])[0]);
      // zone disc, orbit track (dotted) and surface pad
      flatQuad(fillv, c[0], c[1], r * 1.8, r * 1.8, 0, .8, [0, 0, 1, 1], [fc[0], fc[1], fc[2], .09]);
      if (gw.poly) { const n = Math.max(24, Math.round(2 * Math.PI * R.r / 9)); for (let i = 0; i < n; i++) { const an = i / n * 6.2832, q = mapP(R.c[0] + Math.cos(an) * R.r, R.c[1] + Math.sin(an) * R.r, pod); flatQuad(dots, q[0], q[1], 5.5 * S * 1.5, 5.5 * S * 1.5, 0, 2, [0, 0, 1, 1], [.59, .52, .84, .9]); } }
      if (gw.spoly) { const pts = hull(gw.spoly).map(q => { const m = mapP(q[0], q[1], pod); return [m[0], m[1]]; }); fillPoly(zone, pts, .9, [.43, .86, .55, .08]); ribbon(rimv, pts, true, Math.max(1.6, px * 1.1), 1.2, [.43, .86, .55, .55]); }
      // world box: plate, card slot, life slot and base tray, parked beside the world where nothing else is
      const A = ASM && ASM[k]; if (!A) return;
      const P = panelFor(k, ws), t = texOf(P.cv, false); if (P.dirty) { reupload(P.cv); P.dirty = false; }
      const nx = Math.max(A.rect[0], Math.min(c[0], A.rect[2])), nz = Math.max(A.rect[1], Math.min(c[1], A.rect[3])), dd = Math.hypot(nx - c[0], nz - c[1]);
      if (dd > r + 8) { const ux = (nx - c[0]) / dd, uz = (nz - c[1]) / dd; ribbon(rimv, [[c[0] + ux * (r - 6), c[1] + uz * (r - 6)], [nx, nz]], false, Math.max(2, px * 1.5), 1.5, [.62, .78, .95, .8]); }
      const a = []; flatQuad(a, A.x0 + A.w / 2, A.z0 + A.h / 2, A.w, A.h, 0, 3.2, [0, 0, 1, 1], WHITE); pl.push({ tex: t, mode: 0, verts: a });
    });
    // travel lanes from each system's hub world to the other worlds of the system
    Object.keys(D.SYS).forEach(sk => {
      const hk = hubOf(sk), pod = LAY.pods[sk]; if (!hk || !pod || !G.w[hk]) return;
      const A = ringOf(hk), a0 = mapP(A.c[0], A.c[1], pod);
      Object.keys(D.W).forEach(w => {
        if (w === hk || D.W[w].sys !== sk || LAY.pods[w] || !GEO.worlds[w] || !G.w[w]) return;
        const B = ringOf(w), b0 = mapP(B.c[0], B.c[1], pod), dx = b0[0] - a0[0], dz = b0[1] - a0[1], L = Math.hypot(dx, dz), ux = dx / L, uz = dz / L, s0 = A.r * S + 8, s1 = L - B.r * S - 8;
        if (s1 - s0 < 30) return;
        for (let d = s0 + ((T * 26) % 16); d < s1; d += 16) { const u = (d - s0) / (s1 - s0), al = .25 + .5 * Math.sin(u * Math.PI); flatQuad(lanes, a0[0] + ux * d, a0[1] + uz * d, 5, 5, 0, 1.4, [0, 0, 1, 1], [.62, .55, .98, al]); }
        const hx = a0[0] + ux * s1, hz = a0[1] + uz * s1; fillPoly(lanes, [[hx, hz], [hx - ux * 16 - uz * 7, hz - uz * 16 + ux * 7], [hx - ux * 16 + uz * 7, hz - uz * 16 - ux * 7]], 1.4, [.62, .55, .98, .8]);
      });
    });
    flush(pQ, fillv, null, 2); flush(pQ, zone, null, 1); flush(pQ, rimv, null, 1); flush(pQ, dots, null, 2); flush(pQ, lanes, null, 1); batch(pl);
  }
  // ---------- procedural 3D models for the locations that have no printed planet ----------
  // rocks, moons and dwarf planets are ray-marched lumpy spheres (so each one is a real shaded 3D body); clusters orbit a common centre
  const FSR = `precision highp float;varying vec2 vq;uniform float rot,SD,LP,ICE,EL,SC,RG,TT;uniform vec3 L,C1,C2;
    float h3(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
    float n3(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);
      return mix(mix(mix(h3(i),h3(i+vec3(1.,0.,0.)),f.x),mix(h3(i+vec3(0.,1.,0.)),h3(i+vec3(1.,1.,0.)),f.x),f.y),
                 mix(mix(h3(i+vec3(0.,0.,1.)),h3(i+vec3(1.,0.,1.)),f.x),mix(h3(i+vec3(0.,1.,1.)),h3(i+vec3(1.,1.,1.)),f.x),f.y),f.z);}
    float fb(vec3 p){return n3(p)*.5+n3(p*2.1+3.1)*.25+n3(p*4.3+7.7)*.125+n3(p*8.9+1.3)*.0625;}
    vec3 bodyP(vec3 p){float c=cos(rot),s=sin(rot);vec3 b=vec3(c*p.x+s*p.z,p.y,-s*p.x+c*p.z);b.y/=EL;return b;}
    float sdf(vec3 p){vec3 b=bodyP(p);float l=length(b);vec3 d=b/max(l,1e-4);return (l-(1.+LP*(fb(d*1.6+SD)-.5)*1.7))*min(1.,EL+.25);}
    void main(){
      vec2 q=vec2(vq.x*2.-1.,1.-vq.y*2.)*SC;vec3 o=vec3(q,-3.),dv=vec3(0.,0.,1.);
      float t=0.,md=9.;bool hit=false;vec3 p=o,pb=o;
      if(length(q)<1.6){for(int i=0;i<56;i++){p=o+dv*t;float dd=sdf(p);if(dd<md){md=dd;pb=p;}if(dd<.003){hit=true;pb=p;break;}t+=dd*.62;if(t>6.)break;}}
      float tb=hit?t:99.;vec3 Ld=normalize(vec3(L.x,L.y,-L.z));vec4 col=vec4(0.);
      float al=hit?1.:1.-smoothstep(.003,.03,md);
      if(al>0.){
        vec2 e=vec2(.012,0.);
        vec3 N=normalize(vec3(sdf(pb+e.xyy)-sdf(pb-e.xyy),sdf(pb+e.yxy)-sdf(pb-e.yxy),sdf(pb+e.yyx)-sdf(pb-e.yyx)));
        vec3 b=bodyP(pb);float n=fb(b*2.3+SD*1.7);
        vec3 alb=mix(C1,C2,smoothstep(.25,.75,n));
        alb=mix(alb,mix(C1,C2,step(0.,b.x*.9+(n-.5)*.5)),TT);
        float cr=smoothstep(.2,.45,n3(b*4.6+SD*3.)*n3(b*9.1+SD)*2.2);
        alb*=1.-.38*(1.-cr)*(1.-ICE*.5);
        alb=mix(alb,vec3(.93,.97,1.),ICE*.3*fb(b*3.+SD));
        float lam=max(0.,dot(N,Ld));float rim=pow(1.-max(0.,-N.z),3.);
        col=vec4(alb*(.1+1.2*lam)+vec3(.5,.65,.9)*rim*.14*(.4+ICE),al);
      }
      if(RG>0.){vec3 n=normalize(vec3(0.,cos(RG),-sin(RG)*.9));float dn=dot(dv,n);
        if(abs(dn)>.01){float tr=-dot(o,n)/dn;vec3 rp=o+dv*tr;float rr=length(rp);
          if(rr>1.5&&rr<2.2&&tr<tb){float ra=(.5+.5*n3(vec3(rr*40.,SD,0.)))*.62*smoothstep(1.5,1.56,rr)*smoothstep(2.2,2.14,rr);
            vec3 rc=vec3(.6,.55,.5)*(.45+.9*max(0.,abs(dot(n,Ld))));float a=ra+col.a*(1.-ra);
            if(a>0.)col=vec4((rc*ra+col.rgb*col.a*(1.-ra))/a,a);}}}
      if(col.a<=0.)discard;gl_FragColor=col;}`;
  const rkc = (n, seed, c1, c2, o) => { const r = mulb(seed), a = []; for (let i = 0; i < n; i++) a.push(Object.assign({ s: .2 + r() * .32, rho: .5 + r() * 1.5, w: (.1 + r() * .22) * (r() < .5 ? 1 : -1), ph: r() * 6.28, c1, c2, lp: .34, ice: 0, el: .68 + r() * .3, sd: r() * 60, spin: .4 + r(), tt: 0, rg: 0 }, o || {})); return a; };
  const P_ = (o) => Object.assign({ s: 1, rho: 0, w: .12, ph: 0, c1: [.35, .33, .31], c2: [.6, .57, .53], lp: .05, ice: 0, el: 1, tt: 0, rg: 0, sd: 1, spin: .5 }, o);
  const ROCK = [[.3, .27, .24], [.55, .5, .44]], ICY = [[.55, .56, .6], [.9, .92, .96]], RED = [[.28, .1, .06], [.58, .3, .18]];
  // the Scattered Disk's icy bodies, thrown into the free disc inside the transfer-box arc so none touch each other or the boxes
  function scaParts() {
    const U = 18, R = 100, r = mulb(91), spec = [
      [1.3, [.4, .16, .1], [.75, .38, .25], .2], [1.1, [.85, .86, .9], [1, 1, 1], 1], [1, [.3, .32, .4], [.62, .66, .78], .6], [.9, [.5, .25, .15], [.8, .55, .4], .3], [.85, [.32, .34, .42], [.6, .64, .76], .5], [.75, [.7, .72, .8], [.95, .96, 1], .8],
      [.7, [.3, .12, .08], [.62, .32, .22], .2], [.65, [.34, .36, .44], [.64, .68, .8], .5], [.6, [.55, .5, .46], [.85, .8, .74], .3], [.55, [.3, .32, .4], [.6, .64, .76], .6], [.5, [.8, .82, .88], [1, 1, 1], .9], [.45, [.4, .22, .16], [.7, .45, .33], .3]];
    const placed = [], out = [];
    spec.forEach(([s, c1, c2, ice], i) => {
      const rr = U * s * 1.1; let best = null;
      for (let t = 0; t < 4000 && !best; t++) { const a = r() * 6.2832, d = Math.sqrt(r()) * (R - rr), x = Math.cos(a) * d * 1.05, z = Math.sin(a) * d * 1.1 + 34; if (placed.every(q => Math.hypot(q[0] - x, (q[1] - z) * .62) > q[2] + rr + 5)) best = [x, z, rr]; }
      best = best || [(i - 6) * 14, 40, rr]; placed.push(best);
      out.push(P_({ s, rho: Math.hypot(best[0], best[1] / .85) / U, ph: Math.atan2(best[1] / .85, best[0]), w: 0, c1, c2, ice, lp: i % 3 === 1 ? .04 : .2, el: i % 3 === 1 ? 1 : .85, sd: 70 + i * 3, spin: .25 + (i % 4) * .15 }));
    });
    return out;
  }
  const MODELS = {
    nea: { u: 1, parts: rkc(3, 11, ...ROCK, { lp: .38 }).map((p, i) => Object.assign(p, { s: [.8, .55, .42][i], rho: [1.1, 1.5, .9][i] })) },
    pho: { u: 1, parts: [P_({ s: .75, rho: 1, w: .5, lp: .32, el: .8, c1: [.24, .2, .18], c2: [.45, .38, .33], sd: 4 }), P_({ s: .5, rho: 1.8, w: .2, ph: 3, lp: .28, el: .85, c1: [.3, .27, .24], c2: [.55, .5, .45], sd: 9 })] },
    com: { u: 1, parts: [P_({ s: 1, lp: .34, el: .85, c1: [.13, .12, .12], c2: [.34, .3, .27], spin: .3, sd: 7 })], tail: true },
    bel: { u: 1, parts: rkc(9, 21, ...ROCK).map(p => Object.assign(p, { s: p.s * .9 })) },
    hyg: { u: 1, parts: [P_({ s: 1, lp: .08, c1: [.22, .21, .2], c2: [.42, .4, .37], sd: 3 }), P_({ s: .75, rho: 1.9, w: .22, ph: 2, lp: .16, el: .9, c1: [.32, .33, .36], c2: [.52, .53, .56], sd: 5 })] },
    ves: { u: 1, parts: [P_({ s: 1.15, lp: .13, el: .92, c1: [.45, .4, .35], c2: [.88, .85, .8], sd: 8, spin: .8 })] },
    tro: { u: 1, parts: rkc(5, 31, ...ROCK, { rho: 1.7, s: .3 }).map((p, i) => Object.assign(p, { ph: 1.0 + i * .22, w: .1, rho: 1.6 + (i % 2) * .25 })).concat(rkc(5, 32, [.26, .22, .2], [.5, .44, .4], { rho: 1.7, s: .3 }).map((p, i) => Object.assign(p, { ph: 4.1 + i * .22, w: .1, rho: 1.6 + (i % 2) * .25 }))) },
    mim: { u: 1, parts: [P_({ s: .6, rho: 1.3, w: .45, c1: [.5, .5, .52], c2: [.72, .72, .75], ice: .5, sd: 2 }), P_({ s: .65, rho: 0, c1: [.8, .85, .9], c2: [1, 1, 1], ice: 1, sd: 6 }), P_({ s: .8, rho: 2.1, w: .2, ph: 3, c1: [.55, .56, .6], c2: [.85, .86, .9], ice: .8, sd: 12 })] },
    dio: { u: 1, parts: [P_({ s: .85, rho: 1.1, w: .3, c1: [.55, .55, .57], c2: [.85, .86, .88], ice: .7, sd: 14 }), P_({ s: 1.05, rho: 1.1, w: .3, ph: 3.14, c1: [.46, .45, .45], c2: [.78, .78, .78], ice: .4, sd: 17, lp: .04 })] },
    hyp: { u: 1, parts: [P_({ s: .8, rho: 1.8, w: .25, lp: .42, el: .72, c1: [.32, .2, .13], c2: [.62, .42, .28], sd: 19 }), P_({ s: 1, rho: 0, tt: 1, c1: [.1, .08, .07], c2: [.92, .92, .9], ice: .3, lp: .06, sd: 23, spin: .25 })] },
    cha: { u: 1, parts: [P_({ s: .8, lp: .28, el: .85, rg: .55, c1: [.2, .15, .12], c2: [.4, .32, .26], sd: 27 })] },
    obe: { u: 1, parts: [P_({ s: 1.15, rho: 0, c1: [.42, .4, .4], c2: [.72, .7, .68], ice: .4, sd: 31 }), P_({ s: .95, rho: 2.1, w: .25, ph: 2, c1: [.38, .34, .3], c2: [.62, .56, .5], ice: .3, sd: 33 })] },
    umb: { u: 1, parts: [P_({ s: .8, rho: 1.6, w: .32, c1: [.2, .2, .22], c2: [.4, .4, .42], sd: 35 }), P_({ s: .95, rho: 0, c1: [.7, .72, .76], c2: [.95, .96, .98], ice: .8, sd: 37 }), P_({ s: .6, rho: 2.3, w: .18, ph: 3, c1: [.4, .4, .42], c2: [.78, .78, .8], ice: .5, lp: .15, sd: 39 })] },
    gal: { u: 1, parts: [P_({ s: .95, rho: 0, lp: .22, el: .9, c1: [.22, .21, .22], c2: [.42, .4, .4], sd: 41 }), P_({ s: .5, rho: 1.5, w: .5, lp: .3, el: .8, c1: [.2, .2, .2], c2: [.4, .38, .36], sd: 43 }), P_({ s: .42, rho: 2.1, w: .3, ph: 2.5, lp: .3, el: .8, c1: [.25, .24, .24], c2: [.45, .42, .4], sd: 45 })] },
    sca: { u: 1, parts: scaParts() },
    kui: { u: 1, parts: rkc(9, 51, [.32, .34, .4], [.62, .66, .75], { ice: .6 }).concat(rkc(3, 52, [.4, .2, .12], [.7, .42, .28], { ice: .2, s: .35 })) },
    plu: { u: 1, parts: [P_({ s: 1.15, rho: 0, w: 0, lp: .03, c1: [.5, .3, .2], c2: [.97, .92, .84], ice: .35, sd: 49, spin: .35 }), P_({ s: .62, rho: 1.9, w: .32, c1: [.33, .32, .36], c2: [.58, .55, .56], ice: .2, lp: .04, sd: 53 })] },
    hau: { u: 1, parts: [P_({ s: 1.1, rho: 0, el: .55, lp: .08, c1: [.82, .85, .92], c2: [1, 1, 1], ice: 1, sd: 57, spin: 1.6 }), P_({ s: .8, rho: 2.2, w: .15, ph: 3, c1: [.5, .25, .13], c2: [.8, .52, .34], ice: .3, lp: .04, sd: 59 })] },
    sed: { u: 1, parts: [P_({ s: .95, lp: .05, c1: [.22, .05, .03], c2: [.55, .15, .08], sd: 61 })] },
    eri: { u: 1, parts: [P_({ s: 1.15, rho: 0, lp: .02, c1: [.82, .84, .86], c2: [1, 1, 1], ice: 1, sd: 63, spin: .3 }), P_({ s: .38, rho: 2, w: .45, c1: [.18, .18, .2], c2: [.34, .34, .36], lp: .12, sd: 65 })] },
  };
  // canvas-drawn standing models: a space telescope and a solar probe
  const SPRITES = {};
  function hexPts(cx, cy, r) { return Array.from({ length: 6 }, (_, i) => [cx + Math.cos(i * 1.0472 + .5236) * r, cy + Math.sin(i * 1.0472 + .5236) * r]); }
  function spriteFor(k) {
    if (SPRITES[k]) return SPRITES[k];
    const c = document.createElement('canvas'); c.width = c.height = 256; const x = c.getContext('2d');
    if (k === 'dsa') {            // segmented-mirror space telescope with a layered sunshield
      for (let i = 4; i >= 0; i--) { const y = 176 + i * 6, w = 112 - i * 4, g = x.createLinearGradient(128 - w, y, 128 + w, y); g.addColorStop(0, `rgb(${120 + i * 14},${128 + i * 12},${190 + i * 10})`); g.addColorStop(.5, `rgb(${205 + i * 8},${210 + i * 7},${240})`); g.addColorStop(1, `rgb(${110 + i * 14},${118 + i * 12},${180 + i * 10})`); x.fillStyle = g; x.beginPath(); x.moveTo(128 - w, y); x.lineTo(128, y - 30); x.lineTo(128 + w, y); x.lineTo(128, y + 34); x.closePath(); x.fill(); x.strokeStyle = 'rgba(255,255,255,.55)'; x.lineWidth = 1.4; x.stroke(); }
      x.fillStyle = '#39445c'; x.fillRect(110, 126, 36, 46); x.fillStyle = '#56657f'; x.fillRect(110, 126, 36, 8);
      x.strokeStyle = '#8c98ad'; x.lineWidth = 3; x.beginPath(); x.moveTo(128, 126); x.lineTo(128, 18); x.moveTo(128, 126); x.lineTo(104, 40); x.moveTo(128, 126); x.lineTo(152, 40); x.stroke();
      const hexes = []; for (let q = -2; q <= 2; q++) for (let r2 = -2; r2 <= 2; r2++) { const dd = Math.max(Math.abs(q), Math.abs(r2), Math.abs(q + r2)); if (dd === 1 || dd === 2) hexes.push([q, r2]); }
      hexes.forEach(([q, r2]) => { const r = 13.2, cx = 128 + r * 1.732 * (q + r2 / 2), cy = 82 + r * 1.5 * r2, g = x.createRadialGradient(cx - 3, cy - 3, 1, cx, cy, r); g.addColorStop(0, '#ffe9a6'); g.addColorStop(1, '#b8892f'); x.fillStyle = g; x.beginPath(); hexPts(cx, cy, r * 1.0).forEach((pp, i2) => i2 ? x.lineTo(pp[0], pp[1]) : x.moveTo(pp[0], pp[1])); x.closePath(); x.fill(); x.strokeStyle = '#5b431a'; x.lineWidth = 1; x.stroke(); });
      x.fillStyle = '#d5d9e2'; x.beginPath(); x.arc(128, 18, 6, 0, 6.2832); x.fill();
    } else {                      // solar probe: heat shield, body and two small wings
      const g = x.createRadialGradient(118, 100, 8, 128, 112, 92); g.addColorStop(0, '#e9eef5'); g.addColorStop(.7, '#aab4c2'); g.addColorStop(1, '#6c7788');
      x.fillStyle = '#586274'; x.beginPath(); x.moveTo(100, 150); x.lineTo(156, 150); x.lineTo(168, 232); x.lineTo(88, 232); x.closePath(); x.fill();
      x.fillStyle = '#2a4a8f'; [[24, 168, 62, 38], [170, 168, 62, 38]].forEach(([a, b, w, h]) => { x.fillRect(a, b, w, h); x.strokeStyle = '#9db6ee'; x.lineWidth = 1.5; for (let i = 1; i < 4; i++) { x.beginPath(); x.moveTo(a + w * i / 4, b); x.lineTo(a + w * i / 4, b + h); x.stroke(); } x.strokeRect(a, b, w, h); });
      x.fillStyle = g; x.beginPath(); x.ellipse(128, 112, 90, 62, 0, 0, 6.2832); x.fill(); x.strokeStyle = '#fff'; x.lineWidth = 4; x.stroke();
      x.strokeStyle = 'rgba(80,90,105,.55)'; x.lineWidth = 2; for (let i = 1; i < 4; i++) { x.beginPath(); x.ellipse(128, 112, 90 * i / 4, 62 * i / 4, 0, 0, 6.2832); x.stroke(); }
      x.fillStyle = '#dfe6ef'; x.beginPath(); x.arc(128, 200, 12, 0, 6.2832); x.fill(); x.strokeStyle = '#8895a8'; x.lineWidth = 2.4; x.beginPath(); x.moveTo(128, 232); x.lineTo(128, 246); x.stroke();
    }
    return SPRITES[k] = c;
  }
  function billboard(pos, w, h) { const R = [rgt[0] * w, rgt[1] * w, rgt[2] * w], U = [cup[0] * h, cup[1] * h, cup[2] * h]; return [[pos[0] - R[0] + U[0], pos[1] - R[1] + U[1], pos[2] - R[2] + U[2]], [pos[0] + R[0] + U[0], pos[1] + R[1] + U[1], pos[2] + R[2] + U[2]], [pos[0] + R[0] - U[0], pos[1] + R[1] - U[1], pos[2] + R[2] - U[2]], [pos[0] - R[0] - U[0], pos[1] - R[1] - U[1], pos[2] - R[2] - U[2]]]; }
  function drawRock(pos, r, p, T) {
    const sc = p.rg ? 2.4 : 1.45, a = []; quad(a, billboard(pos, r * sc, r * sc), [0, 0, 1, 1], WHITE);
    gl.useProgram(pR); gl.uniformMatrix4fv(pR.u.M, false, vp); gl.bindBuffer(gl.ARRAY_BUFFER, vbo); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(a), gl.DYNAMIC_DRAW);
    const u = pR.u, Ld = norm(sub([0, 0, 0], pos));
    gl.uniform1f(u.rot, p.sd + T * p.spin); gl.uniform1f(u.SD, p.sd); gl.uniform1f(u.LP, p.lp); gl.uniform1f(u.ICE, p.ice); gl.uniform1f(u.EL, p.el); gl.uniform1f(u.SC, sc); gl.uniform1f(u.RG, p.rg); gl.uniform1f(u.TT, p.tt);
    gl.uniform3f(u.C1, p.c1[0], p.c1[1], p.c1[2]); gl.uniform3f(u.C2, p.c2[0], p.c2[1], p.c2[2]); gl.uniform3f(u.L, dot(Ld, rgt), dot(Ld, cup) * .6 + .25, .55);
    gl.drawArrays(gl.TRIANGLES, 0, 6); gl.useProgram(pQ);
  }
  const dist2 = (x, y, z) => (x - eye[0]) ** 2 + (y - eye[1]) ** 2 + (z - eye[2]) ** 2;
  function drawModel(it, T) {
    const u = it.u, sp = it.spec, parts = sp.parts.map(p => { const f = p.ph + p.w * T, o = [it.x + Math.cos(f) * p.rho * u, it.y + Math.sin(f * 1.7) * p.rho * u * .12, it.z + Math.sin(f) * p.rho * u * .85]; return { p, o, d: dist2(o[0], o[1], o[2]) }; });
    if (sp.tail) {
      const L = Math.hypot(it.x, it.z) || 1, dx = it.x / L, dz = it.z / L, g = [], g2 = [];
      for (let i = 0; i < 30; i++) { const t = i / 29, w = Math.sin(T * .8 + i * .5) * u * .25 * t, pos = [it.x + dx * t * u * 8 - dz * w, it.y + t * u * .4, it.z + dz * t * u * 8 + dx * w], rr = u * (.5 + t * 1.9); quad(g, billboard(pos, rr, rr), [0, 0, 1, 1], [.62, .82, 1, .2 * (1 - t) + .02]); }
      for (let i = 0; i < 14; i++) { const t = i / 13, pos = [it.x + dx * t * u * 5.5 + dz * u * .35 * t, it.y, it.z + dz * t * u * 5.5 - dx * u * .35 * t], rr = u * (.3 + t); quad(g2, billboard(pos, rr, rr), [0, 0, 1, 1], [1, .95, .8, .12 * (1 - t)]); }
      quad(g2, billboard([it.x, it.y, it.z], u * 2.2, u * 2.2), [0, 0, 1, 1], [.8, .9, 1, .3]);
      flush(pQ, g, null, 3); flush(pQ, g2, null, 3);
    }
    parts.sort((p, q) => q.d - p.d).forEach(({ p, o }) => drawRock(o, u * p.s, p, T));
  }

  // deep-field art: galaxy sprites (elliptical, spiral, edge-on, lensed arc, diffraction-spike star), all drawn procedurally
  let GALX = null, DEEPBG = null;
  function galaxyAtlas() {      // 4x4 cells of 256 px: spirals with dust lanes and star-forming knots, barred spirals, ellipticals, edge-on discs, rings, irregulars
    if (GALX) return GALX; const CS = 256, c = document.createElement('canvas'); c.width = c.height = CS * 4; const x = c.getContext('2d'), r = mulb(77);
    const glow = (cx, cy, R, col, a, mid) => { const g = x.createRadialGradient(cx, cy, 0, cx, cy, R); g.addColorStop(0, `rgba(${col},${a})`); g.addColorStop(mid || .3, `rgba(${col},${a * .4})`); g.addColorStop(1, `rgba(${col},0)`); x.fillStyle = g; x.beginPath(); x.arc(cx, cy, R, 0, 6.2832); x.fill(); };
    const gauss = () => (r() + r() + r() + r() - 2) / 2;
    const arms = (n, wind, r0, r1, spread, dens, tilt) => {      // star particles along logarithmic-style arms, warm inside and blue outside, with pink star-forming knots
      for (let a = 0; a < n; a++) for (let i = 0; i < dens; i++) {
        const t = Math.pow(i / dens, .8), an = a * 6.2832 / n + t * wind + tilt, rr = r0 + t * (r1 - r0), sp = 2 + t * spread, px = Math.cos(an) * rr + gauss() * sp, py = Math.sin(an) * rr + gauss() * sp;
        const cr = 255 - t * 105 | 0, cg = 226 - t * 30 | 0, cb = 170 + t * 85 | 0; x.fillStyle = `rgba(${cr},${cg},${cb},${.22 + r() * .35})`; x.beginPath(); x.arc(px, py, .6 + r() * 1.7, 0, 6.2832); x.fill();
        if (r() < .012) { glow(px, py, 5 + r() * 5, '255,120,170', .55, .4); }
      }
    };
    const lanes = (n, wind, r0, r1, tilt, off) => { x.save(); x.globalCompositeOperation = 'destination-out'; x.lineCap = 'round'; for (let a = 0; a < n; a++) { x.beginPath(); for (let i = 0; i <= 60; i++) { const t = i / 60, an = a * 6.2832 / n + t * wind + tilt + off, rr = r0 + t * (r1 - r0), px = Math.cos(an) * rr, py = Math.sin(an) * rr; i ? x.lineTo(px, py) : x.moveTo(px, py); } x.strokeStyle = 'rgba(0,0,0,.42)'; x.lineWidth = 5; x.stroke(); x.strokeStyle = 'rgba(0,0,0,.2)'; x.lineWidth = 11; x.stroke(); } x.restore(); };
    for (let n = 0; n < 16; n++) {
      const cx = (n % 4) * CS + CS / 2, cy = ((n / 4) | 0) * CS + CS / 2, ty = n % 8, v = (n / 8) | 0, tilt = r() * 6.2832; x.save(); x.beginPath(); x.rect(cx - CS / 2, cy - CS / 2, CS, CS); x.clip(); x.translate(cx, cy);
      if (ty === 0 || ty === 4) {          // spiral (face-on / inclined)
        const incl = ty === 0 ? .85 - r() * .25 : .38 + r() * .15; x.rotate(r() * 3.14); x.scale(1, incl);
        glow(0, 0, 118, '170,190,255', .18, .5); arms(2 + v, 4.2 + r() * 1.5, 14, 112, 11, 520, tilt); lanes(2 + v, 4.2, 14, 108, tilt, -.2); glow(0, 0, 40, '255,224,165', .9, .35); glow(0, 0, 11, '255,250,238', 1, .5);
      } else if (ty === 1) {               // barred spiral
        x.rotate(r() * 3.14); x.scale(1, .7 - r() * .15); glow(0, 0, 112, '170,190,255', .16, .5);
        const bl = 36, ba = 0; x.save(); x.rotate(ba); x.scale(1, .22); glow(0, 0, bl * 1.5, '255,215,150', .9, .4); x.restore();
        x.save(); x.translate(Math.cos(ba) * bl, Math.sin(ba) * bl); arms(1, 4, 6, 100, 10, 300, ba + 1.57); x.restore(); x.save(); x.translate(-Math.cos(ba) * bl, -Math.sin(ba) * bl); arms(1, 4, 6, 100, 10, 300, ba - 1.57); x.restore();
        glow(0, 0, 22, '255,244,220', .95, .4);
      } else if (ty === 2) {               // giant elliptical with faint shells and globular clusters
        x.rotate(r() * 3.14); x.scale(1, .62 + r() * .3); glow(0, 0, 110, '255,225,175', .5, .6); glow(0, 0, 70, '255,230,185', .8, .45); glow(0, 0, 26, '255,248,230', 1, .5);
        for (let i = 0; i < 26; i++) { const an = r() * 6.2832, d = 30 + r() * 80; x.fillStyle = `rgba(255,235,190,${.3 + r() * .4})`; x.beginPath(); x.arc(Math.cos(an) * d, Math.sin(an) * d, .8 + r() * 1.1, 0, 6.2832); x.fill(); }
      } else if (ty === 3) {               // edge-on disc with a dust lane
        x.rotate(r() * 3.14); x.save(); x.scale(1, .12); glow(0, 0, 118, '255,222,165', .85, .5); x.restore(); x.save(); x.scale(1, .3); glow(0, 0, 40, '255,232,190', .8, .5); x.restore();
        x.save(); x.globalCompositeOperation = 'destination-out'; x.fillStyle = 'rgba(0,0,0,.55)'; x.beginPath(); x.ellipse(0, 1, 100, 2.4, 0, 0, 6.2832); x.fill(); x.restore(); glow(0, -1, 14, '255,248,230', .9, .5);
      } else if (ty === 5) {               // ring galaxy
        x.rotate(r() * 3.14); x.scale(1, .75); x.lineWidth = 12; for (let k = 0; k < 3; k++) { x.strokeStyle = `rgba(150,190,255,${.12 + k * .1})`; x.lineWidth = 16 - k * 5; x.beginPath(); x.ellipse(0, 0, 62, 62, 0, 0, 6.2832); x.stroke(); }
        for (let i = 0; i < 150; i++) { const an = r() * 6.2832, d = 62 + gauss() * 6; x.fillStyle = `rgba(210,225,255,${.3 + r() * .4})`; x.beginPath(); x.arc(Math.cos(an) * d, Math.sin(an) * d, .6 + r() * 1.3, 0, 6.2832); x.fill(); if (r() < .05) glow(Math.cos(an) * d, Math.sin(an) * d, 6, '255,130,170', .6, .4); }
        glow(0, 0, 30, '255,225,170', .9, .4);
      } else if (ty === 6) {               // irregular clumpy dwarf
        x.rotate(r() * 3.14); x.scale(1, .7); for (let i = 0; i < 14; i++) { const an = r() * 6.2832, d = r() * 50; glow(Math.cos(an) * d, Math.sin(an) * d, 14 + r() * 22, r() < .5 ? '140,185,255' : '200,215,255', .45, .5); }
        for (let i = 0; i < 6; i++) glow(gauss() * 40, gauss() * 30, 6 + r() * 4, '255,130,175', .6, .4);
      } else {                             // compact blue galaxy with a bright core
        x.rotate(r() * 3.14); x.scale(1, .6 + r() * .3); glow(0, 0, 70, '120,170,255', .5, .5); glow(0, 0, 26, '200,225,255', .95, .4); glow(0, 0, 8, '255,255,255', 1, .5);
      }
      x.restore();
    }
    return GALX = c;
  }
  function deepBg() {      // wide backdrop: a dim galaxy-cluster field with a haze band through the middle
    if (DEEPBG) return DEEPBG; const W = 2048, H = 1024, c = document.createElement('canvas'); c.width = W; c.height = H; const x = c.getContext('2d'), r = mulb(31337);
    x.fillStyle = '#01030a'; x.fillRect(0, 0, W, H);
    const glow = (cx, cy, R, col, a, sy) => { x.save(); x.translate(cx, cy); x.scale(1, sy || 1); const g = x.createRadialGradient(0, 0, 0, 0, 0, R); g.addColorStop(0, `rgba(${col},${a})`); g.addColorStop(.3, `rgba(${col},${a * .35})`); g.addColorStop(1, `rgba(${col},0)`); x.fillStyle = g; x.beginPath(); x.arc(0, 0, R, 0, 6.2832); x.fill(); x.restore(); };
    for (let i = 0; i < 9; i++) glow(r() * W, H * (.3 + r() * .35), 140 + r() * 220, '210,170,110', .1 + r() * .08, .45);      // diffuse cluster light
    for (let i = 0; i < 520; i++) { const px = r() * W, py = r() * H, R = 2 + Math.pow(r(), 3) * 14, k = r(); x.save(); x.translate(px, py); x.rotate(r() * 3.14); const sy = .25 + r() * .75; x.scale(1, sy);
      const col = k < .55 ? '255,226,170' : k < .8 ? '140,180,255' : '255,130,80'; const g = x.createRadialGradient(0, 0, 0, 0, 0, R); g.addColorStop(0, `rgba(${col},.95)`); g.addColorStop(.35, `rgba(${col},.35)`); g.addColorStop(1, `rgba(${col},0)`); x.fillStyle = g; x.beginPath(); x.arc(0, 0, R, 0, 6.2832); x.fill(); x.restore(); }
    for (let i = 0; i < 40; i++) { const px = r() * W, py = r() * H, L = 18 + r() * 40, an = r() * 3.14; x.strokeStyle = `rgba(255,${120 + r() * 80 | 0},${90 + r() * 60 | 0},.55)`; x.lineWidth = 1.4; x.beginPath(); x.moveTo(px, py); x.lineTo(px + Math.cos(an) * L, py + Math.sin(an) * L); x.stroke(); }
    for (let i = 0; i < 2; i++) { const px = r() * W, py = r() * H; glow(px, py, 22, '255,255,255', 1); x.strokeStyle = 'rgba(190,215,255,.7)'; x.lineWidth = 1.5; x.beginPath(); x.moveTo(px - 46, py); x.lineTo(px + 46, py); x.moveTo(px, py - 46); x.lineTo(px, py + 46); x.stroke(); }
    return DEEPBG = c;
  }
  let NEBA = null;
  function nebulaAtlas() {      // four soft coloured gas clouds, 2x2 cells of 256 px
    if (NEBA) return NEBA; const c = document.createElement('canvas'); c.width = c.height = 512; const x = c.getContext('2d'), r = mulb(555);
    const cols = ['235,90,170', '70,190,200', '140,100,240', '255,150,70'];
    cols.forEach((col, n) => {
      const cx = (n % 2) * 256 + 128, cy = ((n / 2) | 0) * 256 + 128;
      for (let i = 0; i < 46; i++) { const an = r() * 6.2832, d = Math.pow(r(), .7) * 78, px = cx + Math.cos(an) * d, py = cy + Math.sin(an) * d * .75, R = 22 + r() * 52, g = x.createRadialGradient(px, py, 0, px, py, R); g.addColorStop(0, `rgba(${col},${.16 + r() * .14})`); g.addColorStop(1, `rgba(${col},0)`); x.fillStyle = g; x.beginPath(); x.arc(px, py, R, 0, 6.2832); x.fill(); }
      for (let i = 0; i < 18; i++) { const an = r() * 6.2832, d = r() * 60, px = cx + Math.cos(an) * d, py = cy + Math.sin(an) * d, R = 8 + r() * 16, g = x.createRadialGradient(px, py, 0, px, py, R); g.addColorStop(0, 'rgba(255,240,225,.22)'); g.addColorStop(1, 'rgba(255,240,225,0)'); x.fillStyle = g; x.beginPath(); x.arc(px, py, R, 0, 6.2832); x.fill(); }
    });
    return NEBA = c;
  }
  let DEEPI = null;
  function drawDeep(it, T) {      // a still galaxy cluster with gas clouds filling the whole Deep Space Astronomy pod, clear of its world box
    const u = it.u, pod = podOfW('dsa'), rc = pod.rect, ar = ASM && ASM.dsa && ASM.dsa.rect;
    if (!DEEPI || DEEPI.key !== rc.join()) {
      const r = mulb(901), gal = [], neb = [], W = rc[2] - rc[0], H = rc[3] - rc[1];
      const clear = (x, z, s) => !ar || !(x + s * .7 > ar[0] - 20 && x - s * .7 < ar[2] + 20 && z + s * .7 > ar[1] - 20 && z - s * 1.9 < ar[3] + s * 1.4);      // the sprite stands up, so it also reaches north of its foot and hides the box on its south side
      for (let i = 0; i < 9; i++) { let x, z, t = 0, ok; const sz = u * (2 + r() * 1.6); do { x = rc[0] + sz * .5 + (W - sz) * Math.pow(r(), 1.1); z = rc[1] + sz * .4 + (H - sz * .8) * (1 - Math.pow(r(), 1.2)); ok = neb.every(q => Math.hypot(q.x - x, q.z - z) > (q.s + sz) * .62); } while (!(ok && clear(x, z, sz * .5)) && ++t < 200); if (t < 200) neb.push({ x, z, cell: (r() * 4) | 0, s: sz, y: -u * .2 }); }
      for (let i = 0; i < 56; i++) { let x, z, t = 0, ok; const sz = u * (.8 + Math.pow(r(), 1.5) * 1.5) * 1.75; do { x = rc[0] + sz * .6 + (W - sz * 1.2) * Math.pow(r(), 1.25); z = rc[1] + sz * .9 + (H - sz * 1.2) * (1 - Math.pow(r(), 1.3)); ok = gal.every(q => Math.hypot(q.x - x, q.z - z) > (q.s + sz) * .42); } while (!(ok && clear(x, z, sz)) && ++t < 200); if (t < 200) gal.push({ x, z, cell: [0, 8, 1, 9, 4, 12, 2, 10, 0, 1, 4, 2, 3, 5, 6, 7][(r() * 16) | 0], s: sz, y: sz * .5, ph: r() * 6.2832 }); }
      DEEPI = { key: rc.join(), gal, neb };
    }
    const at = galaxyAtlas(), na = nebulaAtlas(), g = [], n = [], gi = DEEPI.gal.map(o => ({ o, d: dist2(o.x, o.y, o.z) }));
    DEEPI.neb.forEach(o => { const cx = (o.cell % 2) / 2, cy = ((o.cell / 2) | 0) / 2; quad(n, billboard([o.x, o.y, o.z], o.s, o.s * .8), [cx, cy, cx + .5, cy + .5], [1, 1, 1, .5]); });
    flush(pQ, n, texOf(na, false), 0);
    gi.sort((p, q) => q.d - p.d);
    gi.forEach(({ o }) => { const cx = (o.cell % 4) / 4, cy = ((o.cell / 4) | 0) / 4, gl = 1 + .06 * Math.sin(T * .7 + o.ph); quad(g, billboard([o.x, o.y, o.z], o.s, o.s), [cx, cy, cx + .25, cy + .25], [gl, gl, gl, .92]); });
    flush(pQ, g, texOf(at, false), 0);
  }
  const ALPHA_PL = { giant: P_({ lp: .015, tt: 1, spin: .7, c1: [.74, .5, .3], c2: [.97, .86, .66], sd: 71 }), b: P_({ lp: .1, c1: [.34, .3, .26], c2: [.62, .55, .48], sd: 72, spin: .8 }), c: P_({ lp: .03, c1: [.3, .4, .55], c2: [.62, .74, .88], sd: 73, spin: .6 }), d: P_({ lp: .12, c1: [.3, .27, .25], c2: [.5, .46, .42], sd: 74, spin: 1 }) };
  function drawStars(it, T) {      // Alpha Centauri A and B circling each other at a fixed distance, a candidate gas giant round the pair, and Proxima with its three planets
    const u = it.u, th = T * .05, at = (r, an, y) => [it.x + Math.cos(an) * r * u, it.y + (y || 0) * u, it.z + Math.sin(an) * r * u], bodies = [];
    const star = (pos, r, c) => bodies.push({ star: true, pos, r, c, d: dist2(pos[0], pos[1], pos[2]) }), planet = (pos, r, part) => bodies.push({ pos, r, part, d: dist2(pos[0], pos[1], pos[2]) });
    // orbits never cross: giant (0.26u) circles A at 1.15u; A and B are 3u apart; Proxima's planets (out to 0.6u) circle Proxima 3.5u from the centre
    const A = at(1.28, th), B = at(1.72, th + Math.PI);
    star(A, .62, [1, .94, .68]); star(B, .46, [1, .62, .3]);
    { const an = T * .4 + 1.1; planet([A[0] + Math.cos(an) * 1.15 * u, A[1] + .05 * u, A[2] + Math.sin(an) * 1.15 * u], .26, ALPHA_PL.giant); }      // the candidate gas giant circles Alpha Centauri A
    const P0 = at(3.5, th * .4 + 3.9); star(P0, .16, [1, .3, .2]);                                                                      // Proxima Centauri, far out and slow
    [[.31, .075, 'b', 2.1], [.44, .066, 'c', 1.3], [.6, .06, 'd', .8]].forEach(([d, r, n, sp], i) => { const an = T * sp * .25 + i * 2.1; planet([P0[0] + Math.cos(an) * d * u, P0[1], P0[2] + Math.sin(an) * d * u], r, ALPHA_PL[n]); });
    bodies.sort((p, q) => q.d - p.d);
    bodies.forEach(o => { if (o.star) { const g = [], a = []; quad(g, billboard(o.pos, o.r * u * 3, o.r * u * 3), [0, 0, 1, 1], [o.c[0], o.c[1], o.c[2], .55]); quad(a, billboard(o.pos, o.r * u, o.r * u), [0, 0, 1, 1], [o.c[0], o.c[1], o.c[2], 1]); flush(pQ, g, null, 3); flush(pQ, a, null, 7); } else drawRock(o.pos, o.r * u, o.part, T); });
  }
  function ensure() {
    if (LAY || typeof GEO === 'undefined' || typeof SHL === 'undefined') return;
    const S0 = typeof FX !== 'undefined' && FX.sun, m = S0 && GEO.maps[S0.map];
    LAY = SHL.build(GEO, D, m ? [m[0] + S0.cx * .4, m[1] + S0.cy * .4] : null);
    V.sunRing = m ? { c: [m[0] + S0.cx * .4, m[1] + S0.cy * .4], r: LAY.sunR * 1.12 / LAY.S } : null;
    ASM = placeAsm(LAY.S);
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
  const podOfW = k => LAY.pods[k] || LAY.pods[D.W[k].sys];
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
    const px = pxw(C.dist);
    // 1 sky
    gl.useProgram(pQ); gl.uniformMatrix4fv(pQ.u.M, false, vp); gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, sky, gl.DYNAMIC_DRAW); gl.uniform1i(pQ.u.MODE, 4); gl.uniform1f(pQ.u.PT, 2.4 * dpr); gl.drawArrays(gl.POINTS, 0, sky.length / 11);
    { const a = [], Sz = 64000; flatQuad(a, 0, 0, Sz, Sz * .5, 0, -9500, [0, 0, 1, 1], [1, 1, 1, .5]); flush(pQ, a, texOf(deepBg(), false), 0); }
    if (typeof FX !== 'undefined' && FX.neb) { const a = [], Sz = 200000, rep = Sz / 9000; flatQuad(a, 0, 0, Sz, Sz, 0, -9000, [0, 0, rep, rep], [1, 1, 1, .55]); flush(pQ, a, texOf(FX.neb, false, true), 0); }
    // 2 belts, orbit rings, spokes
    {
      belts.forEach((b, i) => { gl.useProgram(pQ); gl.uniformMatrix4fv(pQ.u.M, false, vp); gl.bindBuffer(gl.ARRAY_BUFFER, vbo); gl.bufferData(gl.ARRAY_BUFFER, b.pts, gl.DYNAMIC_DRAW); gl.uniform1i(pQ.u.MODE, 4); gl.uniform1f(pQ.u.PT, Math.max(1.8, Math.min(7, 9000 / Math.max(900, C.dist))) * dpr); gl.drawArrays(gl.POINTS, 0, b.pts.length / 11); });
      const a = [], rw = Math.max(9, px * 1.5);
      LAY.rings.concat([{ r: LAY.pods.sca.ring }]).forEach(rg => ribbon(a, circlePts(0, 0, rg.r, 160), true, rw, 1, [.31, .76, .85, .3]));
      for (let k = 0; k < 12; k++) { const an = k / 12 * 6.2832; ribbon(a, [[Math.cos(an) * 700, Math.sin(an) * 700], [Math.cos(an) * 19000, Math.sin(an) * 19000]], false, rw * .55, .5, [.31, .76, .85, .08]); }
      flush(pQ, a, null, 1);
    }
    // 3 pod plates: a dark glass floor with a faint grid under each system; the printed sheets are no longer used
    {
      const a = []; Object.values(LAY.pods).forEach(p => { if (p.k === 'sun') return; const r = p.rect, i = 6; quad(a, [[r[0] + i, 0, r[1] + i], [r[2] - i, 0, r[1] + i], [r[2] - i, 0, r[3] - i], [r[0] + i, 0, r[3] - i]], [(r[0] + i) / 160, (r[1] + i) / 160, (r[2] - i) / 160, (r[3] - i) / 160], [.02, .05, .09, .8]); });
      flush(pQ, a, null, 10);
    }
    drawBeltLinks(T, S, px);
    if (C.dist < 26000) { drawBoxes(T); drawWorlds(T, S, px); }
    { const a = []; Object.values(LAY.pods).forEach(p => { if (p.k === 'sun') return; const r = p.rect, i = 14; ribbon(a, [[r[0] + i, r[1] + i], [r[2] - i, r[1] + i], [r[2] - i, r[3] - i], [r[0] + i, r[3] - i]], true, Math.max(5, px * 1.2), .6, [.31, .76, .85, .22]); }); flush(pQ, a, null, 1); }
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
      gfx.forEach(g => {
        const c = parse(g.color);
        if (g.k === 'ring') { const q = mapP(g.x, g.y); ribbon(a, circlePts(q[0], q[1], g.r * S, 40), true, g.w * 1.4 * S, 3, c); }
        else if (g.k === 'poly') { const pts = mapShape(g.pts); if (g.fill) fillPoly(fill, pts, 2.5, parse(g.fill)); ribbon(a, pts, true, g.w * 1.4 * S, 3, c); }
      });
      if (typeof targets !== 'undefined' && targets) {
        const seen = new Set(), dests = new Set(targets.map(m => m.dest));
        targets.forEach(m => {
          if (seen.has(m.dest)) return; seen.add(m.dest);
          const p = E.P(m.dest), z = zoneShape(m.dest, p.t === 'orbit' && dests.has('surf:' + p.w)), raw = z.poly ? z.poly : circlePts(z.c[0], z.c[1], z.r, 36), pts = BOXSH[m.dest] || mapShape(raw);
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
    if (G) Object.keys(GEO.worlds).forEach(k => {
      if (B && B.b[k]) return;
      const kind = MODELS[k] ? 'rocks' : k === 'dsa' ? 'deep' : k === 'alp' ? 'stars' : null, dw = D.W[k], pod = kind && dw && podOfW(k); if (!pod) return;
      const Rg = ringOf(k), c = mapP(Rg.c[0], Rg.c[1], pod), u = Rg.r * S * .26, y = u * .75;
      items.push({ t: 'model', k, kind, spec: MODELS[k], x: c[0], z: c[1], u, y, d: dist2(c[0], y, c[1]) });
    });
    if (G && LAY.pods.sca) { const hp = LAY.pods.sca, c = mapP(hp.hub[0], hp.hub[1], hp), u = 18, y = u * .75; items.push({ t: 'model', k: 'sca', kind: 'rocks', spec: MODELS.sca, x: c[0], z: c[1], u, y, d: dist2(c[0], y, c[1]) }); }
    stand.forEach(r => { const y = (r.lift || 0) * S + r.h * S / 2; items.push({ t: 'spr', r, d: dist2(r.X, y, r.Z) }); });
    items.sort((p, q) => q.d - p.d);
    { const a = []; items.forEach(it => { if (it.t === 'planet') flatQuad(a, it.x, it.z, it.r * 2.1, it.r * 1.2, 0, 1.6, [0, 0, 1, 1], [0, 0, 0, .38]); else if (it.t === 'model') flatQuad(a, it.x, it.z, it.u * (it.kind === 'sprite' ? 3 : 4.6), it.u * (it.kind === 'sprite' ? 1.8 : 2.8), 0, 1.6, [0, 0, 1, 1], [0, 0, 0, .3]); else if (!it.r.text) flatQuad(a, it.r.X, it.r.Z, it.r.w * S * .9, it.r.w * S * .5, 0, 1.6, [0, 0, 1, 1], [0, 0, 0, .4]); }); flush(pQ, a, null, 2); }
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
      } else if (it.t === 'model') {
        flushRun();
        if (it.kind === 'sprite') { const sz = it.u * (it.k === 'dsa' ? 3.8 : 3.2), cv = spriteFor(it.k), a = []; quad(a, billboard([it.x, it.y + Math.sin(T * 1.2 + it.x) * it.u * .08, it.z], sz, sz), [0, 0, 1, 1], WHITE); flush(pQ, a, texOf(cv, false), 0); }
        else if (it.kind === 'deep') drawDeep(it, T); else if (it.kind === 'stars') drawStars(it, T); else drawModel(it, T);
        const ext = it.u * (it.kind === 'deep' ? 3.4 : it.kind === 'sprite' ? 2.6 : it.k === 'alp' ? 4.4 : 2.4), c = proj(it.x, it.y, it.z), e = proj(it.x + rgt[0] * ext, it.y + rgt[1] * ext, it.z + rgt[2] * ext);
        if (c && e && GEO.worlds[it.k]) picks.push({ sx: c[0], sy: c[1], pr: Math.hypot(e[0] - c[0], e[1] - c[1]), hit: { t: 'world', k: it.k }, z: c[2], planet: true });
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
      Object.values(LAY.pods).forEach(p => { if (p.k === 'sun') return; const q = mapP(p.hub[0], p.hub[1], p); lab(p.name.toUpperCase(), q[0], q[1], p.k); });
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
