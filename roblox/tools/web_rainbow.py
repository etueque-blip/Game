# Радуга после дождя (веб): если днём шёл дождь (сила > 0.4) и он стих (< 0.15), на ~2 минуты напротив солнца
# появляется дуга радиусом 42° (красный снаружи, фиолетовый внутри), нижнюю часть закрывает земля.
# В Roblox то же — в src/client/init.client.luau (Rainbow).
RAINBOW_JS = r"""
// ===== радуга
const RB = { armed: false, t: 0, mesh: null };
function rainbowStep(dt, day) {
  if (RAIN.v > 0.4) RB.armed = true;
  if (RB.armed && RAIN.v < 0.15 && day > 0.6 && SUN_DIR.y > 0.05) { RB.armed = false; RB.t = 120; }
  if (RB.t > 0) RB.t -= dt;
  const a = clamp(Math.min(RB.t / 15, (120 - RB.t) / 10), 0, 1) * day * (1 - MIST.v);
  if (!RB.mesh) {
    const D = 30000, R = D * Math.tan(42 * Math.PI / 180), w = D * Math.tan(2.2 * Math.PI / 180);
    const g = new THREE.RingGeometry(R - w, R, 96, 1);
    const m = new THREE.ShaderMaterial({ transparent: true, depthWrite: false, fog: false, side: THREE.DoubleSide, uniforms: { uA: { value: 0 }, uR0: { value: R - w }, uW: { value: w } },
      vertexShader: "varying vec2 vP; void main(){ vP = position.xy; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }",
      fragmentShader: "uniform float uA; uniform float uR0; uniform float uW; varying vec2 vP; vec3 hue(float h){ return clamp(abs(mod(h*6.0+vec3(0.0,4.0,2.0),6.0)-3.0)-1.0,0.0,1.0); } void main(){ float t = clamp((length(vP)-uR0)/uW, 0.0, 1.0); vec3 c = hue(0.78 - 0.78*t); float edge = smoothstep(0.0,0.15,t)*smoothstep(1.0,0.85,t); gl_FragColor = vec4(c, uA*0.38*edge); }" });
    RB.mesh = new THREE.Mesh(g, m); RB.mesh.renderOrder = -1; RB.mesh.frustumCulled = false; RB.D = D; scene.add(RB.mesh);
  }
  RB.mesh.visible = a > 0.01; if (!RB.mesh.visible) return;
  RB.mesh.material.uniforms.uA.value = a;
  RB.mesh.position.copy(camera.position).addScaledVector(SUN_DIR, -RB.D); RB.mesh.lookAt(camera.position);
}
"""

def add_rainbow(s, patch):
    s = patch(s, "function dayNight(dt) {", RAINBOW_JS + "function dayNight(dt) {")
    s = patch(s, "mistStep(dt, day); stormStep(dt);", "mistStep(dt, day); rainbowStep(dt, day); stormStep(dt);")
    return s
