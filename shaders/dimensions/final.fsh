#include "/lib/settings.glsl"

uniform sampler2D colortex7;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex14;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D noisetex;
uniform sampler2D shadowcolor1;

varying vec2 texcoord;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform float frameTime;
uniform float viewHeight;
uniform float viewWidth;
uniform float aspectRatio;

uniform int hideGUI;

uniform vec3 previousCameraPosition;
// uniform vec3 cameraPosition;
uniform mat4 gbufferPreviousModelView;
// uniform mat4 gbufferModelViewInverse;
// uniform mat4 gbufferModelView;

#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"
#include "/lib/res_params.glsl"

uniform float near;
uniform float far;
float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}

float convertHandDepth_2(in float depth, bool hand) {
	  if(!hand) return depth;

    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    return ndcDepth * 0.5 + 0.5;
}

#include "/lib/util.glsl"
#include "/lib/projections.glsl"

#include "/lib/gameplay_effects.glsl"

void doCameraGridLines(inout vec3 color, vec2 UV){

  float lineThicknessY = 0.001;
  float lineThicknessX = lineThicknessY/aspectRatio;
  
  float horizontalLines = abs(UV.x-0.33);
  horizontalLines = min(abs(UV.x-0.66), horizontalLines);

  float verticalLines = abs(UV.y-0.33);
  verticalLines = min(abs(UV.y-0.66), verticalLines);

  float gridLines = horizontalLines < lineThicknessX || verticalLines < lineThicknessY ? 1.0 : 0.0;

  if(hideGUI > 0.0) gridLines = 0.0;
  color = mix(color, vec3(1.0),  gridLines);
}

vec3 doMotionBlur(vec2 texcoord, float depth, float noise, bool hand){
  
  float samples = 4.0;
  vec3 color = vec3(0.0);

  float blurMult = 1.0;
  if(hand) blurMult = 0.0;

	vec3 viewPos = toScreenSpace(vec3(texcoord, depth));
	viewPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition);

	vec3 previousPosition = mat3(gbufferPreviousModelView) * viewPos + gbufferPreviousModelView[3].xyz;
  previousPosition = toClipSpace3(previousPosition);

	vec2 velocity = texcoord - previousPosition.xy;
  
  // thank you Capt Tatsu for letting me use these
  velocity /= (1.0 + length(velocity)); // ensure the blurring stays sane where UV is beyond 1.0 or -1.0
  velocity /= (1.0 + frameTime*1000.0 * samples * 0.25); // ensure the blur radius stays roughly the same no matter the framerate or sample count
  velocity *= blurMult * MOTION_BLUR_STRENGTH; // remove hand blur and add user control

  texcoord = texcoord - velocity*(samples*0.5 + noise);

  vec2 screenEdges = 2.0/vec2(viewWidth, viewHeight);

	for (int i = 0; i < int(samples); i++) {

    texcoord += velocity;
    color += texture2D(colortex7, clamp(texcoord, screenEdges, 1.0-screenEdges)).rgb;

  }

  return color / samples;
}

float doVignette( in vec2 texcoord, in float noise){

  float vignette = 1.0-clamp(1.0-length(texcoord-0.5),0.0,1.0);
  
  // vignette = pow(1.0-pow(1.0-vignette,3),5);
  vignette *= vignette*vignette;
  vignette = 1.0-vignette;
  vignette *= vignette*vignette*vignette*vignette;
  
  // stop banding
  vignette = vignette + vignette*(noise-0.5)*0.01;
  
  return mix(1.0, vignette, VIGNETTE_STRENGTH);
}

void main() {
  
  float noise = blueNoise();

  #ifdef MOTION_BLUR
    float depth = texture2D(depthtex0, texcoord*RENDER_SCALE).r;
    bool hand = depth < 0.56;
    float depth2 = convertHandDepth_2(depth, hand);

    vec3 COLOR = doMotionBlur(texcoord, depth2, noise, hand);
  #else
    vec3 COLOR = texture2D(colortex7,texcoord).rgb;
  #endif
  
  #if defined LOW_HEALTH_EFFECT || defined DAMAGE_TAKEN_EFFECT || defined WATER_ON_CAMERA_EFFECT  
    // for making the fun, more fun
    applyGameplayEffects(COLOR, texcoord, noise);
  #endif
  
  #ifdef VIGNETTE
    COLOR *= doVignette(texcoord, noise);
  #endif

  #ifdef CAMERA_GRIDLINES
    doCameraGridLines(COLOR, texcoord);
  #endif

  #if DEBUG_VIEW == debug_SHADOWMAP
    vec2 shadowUV = texcoord * vec2(2.0, 1.0) ;

    // shadowUV -= vec2(0.5,0.0);
    // float zoom = 0.1;
    // shadowUV = ((shadowUV-0.5) - (shadowUV-0.5)*zoom) + 0.5;

    if(shadowUV.x < 1.0 && shadowUV.y < 1.0 && hideGUI == 1) COLOR = texture2D(shadowcolor1,shadowUV).rgb;
  #endif
  #if DEBUG_VIEW == debug_DEPTHTEX0
    COLOR = vec3(ld(texture2D(depthtex0, texcoord*RENDER_SCALE).r));
  #endif
  #if DEBUG_VIEW == debug_DEPTHTEX1
    COLOR = vec3(ld(texture2D(depthtex1, texcoord*RENDER_SCALE).r));
  #endif


  gl_FragColor.rgb = COLOR;
}
