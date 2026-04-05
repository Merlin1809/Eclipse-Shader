#include "/lib/settings.glsl"

#include "/lib/SSBOs.glsl"

#ifdef OVERWORLD_SHADER
  in DATA {
    flat vec3 WsunVec;
    flat vec3 WmoonVec;
  };
#endif

uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef DISTANT_HORIZONS
	uniform sampler2D dhDepthTex;
  uniform sampler2D dhDepthTex1;
	#define dhVoxyDepthTex dhDepthTex
  #define dhVoxyDepthTex1 dhDepthTex1
#endif

#ifdef VOXY
  uniform sampler2D vxDepthTexOpaque;
	uniform sampler2D vxDepthTexTrans;
	#define dhVoxyDepthTex vxDepthTexTrans
  #define dhVoxyDepthTex1 vxDepthTexOpaque
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex13;
uniform sampler2D colortex14;
uniform vec2 texelSize;

uniform float viewHeight;
uniform float viewWidth;
uniform float nightVision;
uniform float fogEnd;
uniform vec3 fogColor;
uniform vec3 sunVec;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform float far;
uniform float near;
uniform float farPlane;
uniform float dhVoxyNearPlane;
uniform float dhVoxyFarPlane;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform int hideGUI;
uniform int dhVoxyRenderDistance;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;
uniform float rainStrength;
uniform float blindness;
uniform float darknessFactor;
uniform float darknessLightFactor;
uniform float caveDetection;
uniform float sunElevation;

#if defined CUMULONIMBUS_LIGHTNING && defined OVERWORLD_SHADER && CUMULONIMBUS > 0
  uniform vec4 lightningBoltPosition;

  #include "/lib/scene_controller.glsl"

	uniform sampler2D lightningTex1;
	uniform sampler2D lightningTex2;
	uniform sampler2D lightningTex3;
	uniform sampler2D lightningTex4;
	uniform sampler2D lightningTex5;
	uniform sampler2D lightningTex6;
	uniform sampler2D lightningTex7;
	uniform sampler2D lightningTex8;
	uniform sampler2D lightningTex9;
	uniform sampler2D lightningTex10;
	uniform sampler2D lightningTex11;
	uniform sampler2D lightningTex12;
	uniform sampler2D lightningTex13;
	uniform sampler2D lightningTex14;
	uniform sampler2D lightningTex15;
	uniform sampler2D lightningTex16;

  #define LIGHTNINGONLY
  #include "/lib/volumetricClouds.glsl"
#else
  uniform int worldDay;
#endif

#if defined CUMULONIMBUS_LIGHTNING && CUMULONIMBUS > 0
layout (rgba16f) uniform image2D cloudDepthTex;
#endif

#include "/lib/waterBump.glsl"
#include "/lib/res_params.glsl"

#ifdef OVERWORLD_SHADER
  #include "/lib/climate_settings.glsl"
#endif

#include "/lib/sky_gradient.glsl"

#if RAINBOW > 0 && defined OVERWORLD_SHADER
  uniform float rainbowAmount;
  #include "/lib/hsv.glsl"
#endif

uniform float eyeAltitude;

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

// float ld(float depth) {
//     return 1.0 / (zMults.y - depth * zMults.z);		// (-depth * (far - near)) = (2.0 * near)/ld - far - near
// }

float convertHandDepth(float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    return ndcDepth * 0.5 + 0.5;
}

float linearize(float dist) {
  return (2.0 * near) / (far + near - dist * (far - near));
}

float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}

vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 playerPos = p * 2. - 1.;
    vec4 fragposition = iProjDiag * playerPos.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

#include "/lib/DistantHorizons_projections.glsl"

float interleaved_gradientNoise_temporal(){
	#ifdef TAA
		return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y ) + 1.0/1.6180339887 * frameCounter);
	#else
		return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y ) + 1.0/1.6180339887);
	#endif
}

float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}

float R2_dither(){
	vec2 coord = gl_FragCoord.xy ;

	#ifdef TAA
		coord +=  (frameCounter%40000) * 2.0;
	#endif
	
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}

float blueNoise(){
	#ifdef TAA
  		return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
	#else
		return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887);
	#endif
}

vec4 blueNoise(vec2 coord){
  return texelFetch(colortex6, ivec2(coord)%512 , 0) ;
}

vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}

float DH_ld(float dist) {
    return (2.0 * dhVoxyNearPlane) / (dhVoxyFarPlane + dhVoxyNearPlane - dist * (dhVoxyFarPlane - dhVoxyNearPlane));
}

float DH_inv_ld (float lindepth){
	return -((2.0*dhVoxyNearPlane/lindepth)-dhVoxyFarPlane-dhVoxyNearPlane)/(dhVoxyFarPlane-dhVoxyNearPlane);
}

float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
}

vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}

vec3 decode (vec2 encn){
    vec3 n = vec3(0.0);
    encn = encn * 2.0 - 1.0;
    n.xy = abs(encn);
    n.z = 1.0 - n.x - n.y;
    n.xy = n.z <= 0.0 ? (1.0 - n.yx) * sign(encn) : encn;
    return clamp(normalize(n.xyz),-1.0,1.0);
}

vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
}

vec3 viewToWorld(vec3 viewPosition) {
    vec4 pos;
    pos.xyz = viewPosition;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}

vec2 clampUV(in vec2 uv, vec2 texcoord){
  // return uv;

  // get the gradient when a refracted axis and non refracted axis go above 1.0 or below 0.0
  // use this gradient to lerp between refracted and non refracted uv
  // the goal of this is to stretch the uv back to normal when the refracted image exposes off screen uv
  // emphasis on *stretch*, as i want the transition to remain looking like refraction, not a sharp cut.

  float vignette = max(uv.x * texcoord.x, 0.0);
  vignette = max(uv.y * texcoord.y, vignette);
  vignette = max((uv.x-1.0) * (texcoord.x-1.0), vignette);
  vignette = max((uv.y-1.0) * (texcoord.y-1.0), vignette);
  vignette *= vignette*vignette*vignette*vignette;

  return clamp(mix(uv, texcoord, vignette),0.0,0.9999999);
}

vec3 doRefractionEffect( inout vec2 passTexcoord, vec2 normal, float linearDistance, bool isReflectiveEntity, bool underwater){
  // correct normal directions to match texcoord directions (right facing X, up facing Y)
  normal.y = -normal.y;
  vec2 texcoord = passTexcoord;

  vec3 color = vec3(0.0);

  float refractAmount = float(FAKE_REFRACTION_AMOUNT)/4.0;
  float dispersionAmount = float(FAKE_DISPERSION_AMOUNT)/4.0;
  float smudgeAmount = float(REFRACTION_SMUDGE_AMOUNT)/4.0;

  refractAmount *= 0.5 / (1.0 + pow(linearDistance,0.8) * (underwater ? 0.1 : 1.0));
  if(isReflectiveEntity) refractAmount *= 0.5;

  dispersionAmount *= 0.035;
  smudgeAmount *= 0.035;

  vec2 dispersion = (clamp(normal, -0.2, 0.2) / 0.2);
  
  #if REFRACTION_SMUDGE_AMOUNT > 0
    vec2 smudge = smudgeAmount * dispersion * (blueNoise()-0.5);
  #else
    vec2 smudge = vec2(0.0, 0.0);
  #endif

  dispersion *= dispersionAmount;

  #if FAKE_DISPERSION_AMOUNT > 0
    // do not offset texcoord if alpha is 1.0
    refractAmount *= min(  decodeVec2(texelFetch(colortex11, ivec2(clampUV(texcoord - ((normal + dispersion) + smudge)*refractAmount, texcoord)/texelSize),0).b).g,
                           decodeVec2(texelFetch(colortex11, ivec2(clampUV(texcoord - ((normal - dispersion) + smudge)*refractAmount, texcoord)/texelSize),0).b).g  ) > 0.0 ? 1.0 : 0.0;

    // create offsets
    vec2 offsetTexcoord = clampUV(texcoord - (normal + smudge)*refractAmount, texcoord);
    passTexcoord = offsetTexcoord;

    // sample color with offsetted texcoord. in this case, the red and blue channels have offsets in opposite directions for a dispersion effect.
    color.g = texture(colortex3, offsetTexcoord).g;

    offsetTexcoord = clampUV(texcoord - ((normal + dispersion) + smudge)*refractAmount, texcoord);
    color.r = texture(colortex3, offsetTexcoord).r;

    offsetTexcoord = clampUV(texcoord - ((normal - dispersion) + smudge)*refractAmount, texcoord);
    color.b = texture(colortex3, offsetTexcoord).b;
  #else
    // do not offset texcoord if alpha is 1.0
    refractAmount *= decodeVec2(texelFetch(colortex11, ivec2(clampUV(texcoord - (normal + smudge)*refractAmount, texcoord)/texelSize),0).b).g > 0.0 ? 1.0 : 0.0; 

    // create offsets
    vec2 offsetTexcoord = clampUV(texcoord - (normal + smudge)*refractAmount, texcoord);
    passTexcoord = offsetTexcoord;

    // sample color with distorted texcoords
    color.rgb = texture(colortex3, offsetTexcoord).rgb;
  #endif

  return color;
}

vec3 toClipSpace3Prev(vec3 viewSpacePosition) {
    return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

vec3 toClipSpace3Prev_DH( vec3 viewSpacePosition, bool depthCheck ) {

	#if defined DISTANT_HORIZONS || defined VOXY
		mat4 projectionMatrix = depthCheck ? dhVoxyProjectionPrev : gbufferPreviousProjection;
   		return projMAD(projectionMatrix, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#else
    	return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#endif
}

vec4 bilateralUpsample(vec2 fragcoord, sampler2D colortex, out float outerEdgeResults, float referenceDepth, sampler2D depth, bool hand, const int behindTranslucents){

  vec4 colorSum = vec4(0.0);
  float edgeSum = 0.0;
  #if defined DISTANT_HORIZONS || defined VOXY
    const float threshold = 0.05;
  #else
    const float threshold = 0.005;
  #endif

  #ifdef HQ_CLOUD_UPSAMPLE
    const int samples = 9;
  #else
    const int samples = 5;
  #endif
  
  vec2 coord = fragcoord - 1.5;

  vec2 UV = coord;
  const ivec2 SCALE = ivec2(1.0/VL_RENDER_SCALE);
  ivec2 UV_DEPTH = ivec2(UV*VL_RENDER_SCALE)*SCALE;
  ivec2 UV_COLOR = ivec2(UV*VL_RENDER_SCALE);
  ivec2 UV_NOISE = ivec2(gl_FragCoord.xy*texelSize + 1);

	const ivec2 OFFSET[9] = ivec2[9](
    ivec2(-1,-1),
	 	ivec2( 1, 1),
		ivec2(-1, 1),
		ivec2( 1,-1),
		ivec2( 0, 0),
    ivec2( 0, 1),
    ivec2( 0,-1),
    ivec2( 1, 0),
    ivec2(-1, 0)
  );

  for(int i = 0; i < samples; i++) {

		#if defined DISTANT_HORIZONS || defined VOXY
      float offsetDepth = sqrt(texelFetch(depth, UV_DEPTH + (OFFSET[i] + UV_NOISE) * SCALE,0)[behindTranslucents]);
    #else
      float offsetDepth = linearize(texelFetch(depth, UV_DEPTH + (OFFSET[i] + UV_NOISE) * SCALE, 0).r);
    #endif

    float edgeDiff = abs(offsetDepth - referenceDepth) < threshold ? 1.0 : 1e-7;
    outerEdgeResults = max(outerEdgeResults, abs(referenceDepth - offsetDepth));

    vec4 offsetColor = texelFetch(colortex, UV_COLOR + OFFSET[i] + UV_NOISE, 0);
    colorSum += offsetColor*edgeDiff;
    edgeSum += edgeDiff;

  }

  outerEdgeResults = outerEdgeResults > (hand ? 0.005 : referenceDepth*0.05 + 0.1) ? 1.0 : 0.0;
  
  return colorSum / edgeSum;
}

vec4 VLTemporalFiltering(vec3 playerPosIn, in float referenceDepth, sampler2D depth, bool hand){
  vec2 screenEdges = 2.0/vec2(viewWidth, viewHeight);
  vec2 offsetTexcoord = clamp(gl_FragCoord.xy*texelSize, screenEdges, 1.0-screenEdges);
  vec2 VLtexCoord = offsetTexcoord * VL_RENDER_SCALE;
  
	// get previous frames position stuff for UV
	vec3 playerPos = playerPosIn + (cameraPosition - previousCameraPosition);
	vec3 previousPosition = mat3(gbufferPreviousModelView) * playerPos + gbufferPreviousModelView[3].xyz;
	previousPosition = toClipSpace3Prev(previousPosition);

	vec2 velocity = previousPosition.xy - offsetTexcoord;
	previousPosition.xy = offsetTexcoord + velocity;

  vec4 currentFrame = texture(colortex0, VLtexCoord);

  // return vec4(outerEdgeResults,0,0,1);
  // return upsampledCurrentFrame;

  if (previousPosition.x < 0.0 || previousPosition.y < 0.0 || previousPosition.x > 1.0 || previousPosition.y > 1.0) return currentFrame;

  // to fill pixel gaps in geometry edges, do a bilateral upsample.
  // pass a mask to only show upsampled color around the edges of blocks. this is so it doesnt blur reprojected results.
  float outerEdgeResults = 0.0;
  vec4 upsampledCurrentFrame = bilateralUpsample(gl_FragCoord.xy , colortex0, outerEdgeResults, referenceDepth, depth, hand, 2);
  // vec4 upsampledCurrentFrame = BilateralUpscale(colortex0, depth, gl_FragCoord.xy - 1.5, referenceDepth);
  
	vec4 col1 = texture(colortex0, VLtexCoord + vec2( texelSize.x,  texelSize.y));
	vec4 col2 = texture(colortex0, VLtexCoord + vec2( texelSize.x, -texelSize.y));
	vec4 col3 = texture(colortex0, VLtexCoord + vec2(-texelSize.x, -texelSize.y));
	vec4 col4 = texture(colortex0, VLtexCoord + vec2(-texelSize.x,  texelSize.y));
	vec4 col5 = texture(colortex0, VLtexCoord + vec2( 0.0,			    texelSize.y));
	vec4 col6 = texture(colortex0, VLtexCoord + vec2( 0.0,			   -texelSize.y));
	vec4 col7 = texture(colortex0, VLtexCoord + vec2(-texelSize.x,  		    0.0));
	vec4 col8 = texture(colortex0, VLtexCoord + vec2( texelSize.x,  		    0.0));

	vec4 colMax = max(currentFrame,max(col1,max(col2,max(col3, max(col4, max(col5, max(col6, max(col7, col8))))))));
	vec4 colMin = min(currentFrame,min(col1,min(col2,min(col3, min(col4, min(col5, min(col6, min(col7, col8))))))));
  
  vec4 frameHistory = texture(colortex10, previousPosition.xy*RENDER_SCALE);
  vec4 clampedFrameHistory = clamp(frameHistory, colMin, colMax);

  float blendingFactor = 0.1;

  // variance
  if(abs(clampedFrameHistory.a  - frameHistory.a) > 0.1) blendingFactor = 1.0;

  vec4 reprojectFrame = mix(clampedFrameHistory, currentFrame, blendingFactor);

  // return clamp(reprojectFrame,0.0,65000.0);
  return clamp(mix(reprojectFrame, upsampledCurrentFrame, outerEdgeResults),0.0,65000.0);

}

uniform float waterEnteredAltitude;

void blendAllFogTypes( inout vec3 color, inout float bloomyFogMult, vec4 volumetrics, float linearDistance, vec3 playerPos, vec3 cameraPosition, bool isSky, bool isLightning){

  // blend cave fog
  #if defined OVERWORLD_SHADER && defined CAVE_FOG
    if (isEyeInWater == 0 && eyeAltitude < 1500){
      vec3 cavefogCol = vec3(CaveFogColor_R, CaveFogColor_G, CaveFogColor_B) * 0.3;
      cavefogCol *= 1.0-pow(1.0-pow(1.0 - max(1.0 - linearDistance/far,0),2),CaveFogFallOff);
      cavefogCol *= exp(-7.0*clamp(playerPos.y*0.5+0.5,0,1)) * 0.999 + 0.001;

      float skyhole = pow(clamp(1.0-pow(max(playerPos.y - 0.6,0.0)*5.0,2.0),0.0,1.0),2);

      #if CAVE_DETECTION < 2
        #if CAVE_DETECTION == 1
          float caveFactor = 1.0 - smoothstep(60.0, 63.0, cameraPosition.y);
        #else
          const float caveFactor = 1.0;
        #endif
      #else
        const float caveFactor = 0.0;
      #endif

      color.rgb = mix(color.rgb + cavefogCol * caveDetection, cavefogCol, isSky ? skyhole * caveDetection * caveFactor: 0.0);
    }
  #endif

  /// water absorption; it is completed when volumetrics are blended.
  if(isEyeInWater == 1){
    vec3 totEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
		vec3 scatterCoef = Dirt_Amount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;

	  float distanceFromWaterSurface = playerPos.y + 1.0 + (cameraPosition.y - waterEnteredAltitude)/waterEnteredAltitude;
    distanceFromWaterSurface = clamp(distanceFromWaterSurface,0,1);

    vec3 transmittance = exp(-totEpsilon * linearDistance);
    color.rgb *= transmittance;

    vec3 transmittance2 = exp(-totEpsilon * 50.0);
    float fogfade = 1.0 - max((1.0 - linearDistance / min(far, 16.0*7.0) ),0);
    color.rgb += (transmittance2 * scatterCoef) * fogfade;
    
    bloomyFogMult *= dot(transmittance,vec3(0.3333))*0.75 + 0.25;
  }

  /// blend volumetrics
  if(!isLightning) color = color * volumetrics.a;
  color += volumetrics.rgb;
  
  // make bloomy fog only work outside of the overworld (unless underwater)
  #if !defined OVERWORLD_SHADER
    bloomyFogMult = min(bloomyFogMult, volumetrics.a);
  #endif

  // blend vanilla fogs (blindness, darkness, lava, powdered snow)
  if(isEyeInWater > 1 || blindness > 0 || darknessFactor > 0){
    float enviornmentFogDensity = 1.0 - clamp(linearDistance/fogEnd,0,1);
    enviornmentFogDensity = 1.0 - enviornmentFogDensity*enviornmentFogDensity;
    enviornmentFogDensity *= enviornmentFogDensity;
    enviornmentFogDensity =  mix(enviornmentFogDensity, 1.0, min(darknessLightFactor*2.0,1));

    color = mix(color, toLinear(fogColor), enviornmentFogDensity);
  }
}

void blendForwardRendering( inout vec3 color, vec4 translucentShader ){
  // REMEMBER that forward rendered color is written as color.rgb/10.0, invert it.
  if(translucentShader.a > 0) {
    color = color * (1.0 - translucentShader.a) + translucentShader.rgb * 10.0;
  }
}

float getBorderFogDensity(float linearDistance, vec3 playerPos, bool sky){

  if(sky) return 0.0;

  #if defined DISTANT_HORIZONS || defined VOXY
  	float borderFogDensity = smoothstep(1.0, 0.0, min(max(1.0 - linearDistance / dhVoxyRenderDistance,0.0)*3.0/BorderFogIntensity,1.0)   );
  #else
  	float borderFogDensity = smoothstep(1.0, 0.0, min(max(1.0 - linearDistance / far,0.0)*3.0/BorderFogIntensity,1.0)   );
  #endif
  
  borderFogDensity *= exp(-10.0 * pow(clamp(playerPos.y,0.0,1.0)*4.0,2.0));
  borderFogDensity *= (1.0-caveDetection);

  return borderFogDensity;
}

#if AURORA_LOCATION > 0
  uniform float auroraAmount;
  #include "/lib/aurora.glsl"
#endif

void main() {
  /* RENDERTARGETS:7,3,10 */

	////// --------------- SETUP STUFF --------------- //////
  vec2 texcoord = gl_FragCoord.xy*texelSize;
  float depth = texelFetch(depthtex0, ivec2(gl_FragCoord.xy),0).x;
  bool hand = depth < 0.56;
  float z = depth;

  float frDepth = linearize(z);

	#if defined DISTANT_HORIZONS || defined VOXY
    float DH_depth0 = 0.0;
    bool isDHrange = z >= 1.0;
    if(isDHrange) DH_depth0 = texelFetch(dhVoxyDepthTex, ivec2(gl_FragCoord.xy),0).x;

    bool isSky = DH_depth0 >= 1.0;
	#else
    bool isSky = z >= 1.0;
		float DH_depth0 = 1.0;
	#endif

  #if !defined DISTANT_HORIZONS && !defined VOXY || (AURORA_LOCATION > 0 && defined OVERWORLD_SHADER)
    float z2 = texelFetch(depthtex1, ivec2(gl_FragCoord.xy),0).x;
  #endif

  #if AURORA_LOCATION > 0 && defined OVERWORLD_SHADER
    #if defined DISTANT_HORIZONS || defined VOXY
      float DH_depth1 = texelFetch(dhVoxyDepthTex, ivec2(gl_FragCoord.xy),0).x;
      bool isSkyTranslucent = z2 >= 1.0 && DH_depth1 >= 1.0;
    #else
      bool isSkyTranslucent = z2 >= 1.0;
    #endif
  #endif

	vec3 viewPos = toScreenSpace_DH(texcoord/RENDER_SCALE, z, DH_depth0);
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;

  float linearDistance = length(playerPos);
  float linearDistance_cylinder = length(playerPos.xz);
	vec3 playerPos_normalized = normalize(playerPos);

  #if !defined DISTANT_HORIZONS && !defined VOXY
    vec3 viewPos_alt = toScreenSpace(vec3(texcoord/RENDER_SCALE, z2));
    vec3 playerPos_alt = mat3(gbufferModelViewInverse) * viewPos_alt + gbufferModelViewInverse[3].xyz;
    float linearDistance_cylinder_alt = length(playerPos_alt.xz);
  #endif

	// float lightleakfix = clamp(pow(eyeBrightnessSmooth.y/240.,2.) ,0.0,1.0);
	// float lightleakfixfast = clamp(eyeBrightness.y/240.,0.0,1.0);

	////// --------------- UNPACK OPAQUE GBUFFERS --------------- //////
	// float opaqueMasks = decodeVec2(texture(colortex1,texcoord).a).y;
	// bool isOpaque_entity = abs(opaqueMasks-0.45) < 0.01;

	////// --------------- UNPACK TRANSLUCENT GBUFFERS --------------- //////
	vec4 data = texelFetch(colortex11,ivec2(texcoord/texelSize),0).rgba;
	vec4 unpack0 = vec4(decodeVec2(data.r),decodeVec2(data.g));
	vec2 unpack1 = decodeVec2(data.b);
	
	vec4 albedo = vec4(unpack0.ba,unpack1);
	vec2 tangentNormals = unpack0.xy*2.0-1.0;
  
	bool nameTagMask = abs(data.a - 0.1) < 0.01;
  float nametagbackground = nameTagMask ? 0.25 : 1.0;

  if(albedo.a < 0.01) tangentNormals = vec2(0.0);

	////// --------------- UNPACK MISC --------------- //////
	// 1.0 = water mask
	// 0.9 = entity mask
	// 0.8 = reflective entities
	// 0.7 = reflective blocks
  float translucentMasks = texelFetch(colortex7, ivec2(gl_FragCoord.xy),0).a;

	bool isWater = translucentMasks > 0.99;
	bool isReflectiveEntity = abs(translucentMasks - 0.2) < 0.01;
	bool isReflective = abs(translucentMasks - 0.1) < 0.01 || isWater || isReflectiveEntity;
	bool isEntity = abs(translucentMasks - 0.4) < 0.01 || isReflectiveEntity;

  ////// --------------- get volumetrics
  #if defined DISTANT_HORIZONS || defined VOXY
	  float DH_mixedLinearZ = sqrt(texelFetch(colortex9,ivec2(gl_FragCoord.xy),0).z);
    vec4 temporallyFilteredVL = VLTemporalFiltering(playerPos, DH_mixedLinearZ, colortex9, hand);
  #else
    vec4 temporallyFilteredVL = VLTemporalFiltering(playerPos, frDepth, depthtex0, hand);
  #endif

  gl_FragData[2] = temporallyFilteredVL;
  float bloomyFogMult = 1.0;

  ////// --------------- MAIN COLOR BUFFER
  ////// --------------- distort texcoords as a refraction effect
  vec2 refractedCoord = texcoord;
  #if FAKE_REFRACTION_AMOUNT > 0
    vec3 color;
    #if defined DISTANT_HORIZONS || defined VOXY

    bool isLOD = abs(data.a - 0.5) < 0.01;
    if(isDHrange || hand || isLOD) {
      color = texture(colortex3, texcoord).rgb;
    }
    else
    #endif
    {
      color = doRefractionEffect(refractedCoord, tangentNormals.xy, linearDistance, isReflectiveEntity, isWater && isEyeInWater == 1);
    }
  #else
    vec3 color = texture(colortex3, texcoord).rgb;
  #endif

  ////// --------------- lightning effect

  bool isLightning = false;

  #if defined OVERWORLD_SHADER && defined CUMULONIMBUS_LIGHTNING && CUMULONIMBUS > 0 && defined VOLUMETRIC_CLOUDS

    vec2 cloudDepth = imageLoad(cloudDepthTex, ivec2(gl_FragCoord.xy*VL_RENDER_SCALE*RENDER_SCALE)).rg;

    vec3 lightningpos = vec3(getLightningPosition(600, 4680));
    //lightningpos =  vec3(0,0,1);

    float lightningDist = length(lightningpos);

    if ((lightningDist < cloudDepth.r || cloudDepth.r == 0.0) && (thunderStrength > 0.0 || rainStrength == 0.0)) {
      vec2 tc = (gl_FragCoord.xy - 0.5)*texelSize;

      float depth = z;
      
      float z0 = depth < 0.56 ? convertHandDepth(depth) : depth;

      float uvScalar = 3.0 * CUSTOM_LIGHTNING_SCALE;

      vec3 normLightningpos = normalize(lightningpos);
      
      vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * toScreenSpace(vec3(texcoord /RENDER_SCALE,1.0)));

      vec3 tangent = normalize(cross(normLightningpos, vec3(0.0, 1.0, 0.0)));
      vec3 binormal = cross(normLightningpos, tangent);
      vec3 dirDiff = worldDir - normLightningpos;

      float u = -1.0;
      float v = -1.0;
      vec4 lightningTex = vec4(0.0);
      if (dot(worldDir, normLightningpos) > 0.0) {
        u = dot(dirDiff, tangent) + 0.5/uvScalar;
        v = 0.55*dot(dirDiff, binormal) + 0.1/uvScalar;

        vec2 uv = vec2(u, v) * uvScalar;

        float randomTex = 16.0*rand(lightningTimer*72.82723486);

        #if CUSTOM_LIGHTNING_TEX > 0
          randomTex = CUSTOM_LIGHTNING_TEX - 1.0;
        #endif

        // TODO: There has to be a better way to do this.............
        if (randomTex < 1.0) {
          lightningTex = texture(lightningTex1, uv);
        } else if (randomTex < 2.0) {
          lightningTex = texture(lightningTex2, uv);
        } else if (randomTex < 3.0) {
          u = 1.3*dot(dirDiff, tangent) + 0.5/uvScalar;
          uv = vec2(u, v) * uvScalar;
          lightningTex = texture(lightningTex3, uv);
        } else if (randomTex < 4.0) {
          lightningTex = texture(lightningTex4, uv);
        } else if (randomTex < 5.0) {
          lightningTex = texture(lightningTex5, uv);
        } else if (randomTex < 6.0) {
          u = 1.25*dot(dirDiff, tangent) + 0.5/uvScalar;
          uv = vec2(u, v) * uvScalar;
          lightningTex = texture(lightningTex6, uv);
        } else if (randomTex < 7.0) {
          lightningTex = texture(lightningTex7, uv);
        } else if (randomTex < 8.0) {
          lightningTex = texture(lightningTex8, uv);
        } else if (randomTex < 9.0) {
          u = 1.4*dot(dirDiff, tangent) + 0.5/uvScalar;
          uv = vec2(u, v) * uvScalar;
          lightningTex = texture(lightningTex9, uv);
        } else if (randomTex < 10.0) {
          lightningTex = texture(lightningTex10, uv);
        } else if (randomTex < 11.0) {
          u = 0.5*dot(dirDiff, tangent)+0.5/uvScalar;
          v = 0.7*dot(dirDiff, binormal) + 0.5/uvScalar;
          uv = vec2(u, v) * uvScalar;
          lightningTex = texture(lightningTex11, uv);
        } else if (randomTex < 12.0) {
          u = 0.45*dot(dirDiff, tangent)+0.5/uvScalar;
          v = 0.7*dot(dirDiff, binormal) + 0.5/uvScalar;
          uv = vec2(u, v) * uvScalar;
          lightningTex = texture(lightningTex12, uv);
        } else if (randomTex < 13.0) {
          u = 0.45*dot(dirDiff, tangent)+0.5/uvScalar;
          v = 0.7*dot(dirDiff, binormal) + 0.5/uvScalar;
          uv = vec2(u, v) * uvScalar;
          lightningTex = texture(lightningTex13, uv);
        } else if (randomTex < 14.0) {
          u = 0.5*dot(dirDiff, tangent)+0.5/uvScalar;
          v = 0.7*dot(dirDiff, binormal) + 0.5/uvScalar;
          uv = vec2(u, v) * uvScalar;
          lightningTex = texture(lightningTex14, uv);
        } else if (randomTex < 15.0) {
          u = 0.45*dot(dirDiff, tangent)+0.5/uvScalar;
          v = 0.7*dot(dirDiff, binormal) + 0.5/uvScalar;
          uv = vec2(u, v) * uvScalar;
          lightningTex = texture(lightningTex15, uv);
        } else {
          u = 0.4*dot(dirDiff, tangent)+0.5/uvScalar;
          v = 0.7*dot(dirDiff, binormal) + 0.5/uvScalar;
          uv = vec2(u, v) * uvScalar;
          lightningTex = texture(lightningTex16, uv);
        }

        lightningTex.rgb *= vec3(CUSTOM_LIGHTNING_R, CUSTOM_LIGHTNING_G, CUSTOM_LIGHTNING_B) * CUMULONIMBUS_LIGHTNING_BRIGHTNESS * 0.01;

        if(cloudDepth.g > 0.0) lightningTex.rgb *= smoothstep(7000.0, 1500.0, lightningDist - cloudDepth.g);

        if(lightningTex.rgb != vec3(0.0)) {
          #if defined CUSTOM_LIGHTNING_POS && CUSTOM_LIGHTNING_TEX > 0
            lightningTex.a *= pow(lightningTex.a, 2.0);

            lightningTex.rgb *= 75;
          #else
            lightningTex.a *= pow(lightningTex.a, lightningStart); // fade alpha in for cool expansion effect

            lightningTex.rgb += 120 * lightningMid * lightningTex.rgb; // bright flash in the middle

            lightningTex.rgb *= 75 * lightningFade; // fade out
          #endif
        }

        if (length(lightningTex.rgb) == 0.0) lightningTex.a = 0.0;
      }

      // bool isSky = z0 == 1.0 && DH_z0 == 1.0;
      bool oneTexOnly = u > 0 && v > 0 && u*uvScalar < 1 && v*uvScalar < 1;
      
      if (lightningTex.a > 0.01 && oneTexOnly && isSky) {
        color = lightningTex.rgb * lightningFlash;
        isLightning = true;
      }
    }
  #endif

  ////// --------------- get volumetrics behind translucents
  float blank = 0.0;
  #if defined DISTANT_HORIZONS || defined VOXY
    DH_mixedLinearZ = sqrt(texelFetch(colortex9,ivec2(gl_FragCoord.xy),0).a);
    vec4 VLBehindTranslucents = bilateralUpsample(refractedCoord/texelSize, colortex13, blank, DH_mixedLinearZ, colortex9, hand, 3);
  #else
    vec4 VLBehindTranslucents = bilateralUpsample(refractedCoord/texelSize, colortex13, blank, linearize(texelFetch(depthtex1, ivec2(refractedCoord/texelSize),0).x), depthtex1, hand, 3);
  #endif

  ////// --------------- START BLENDING FOGS AND FORWARD RENDERED COLOR
  vec4 TranslucentShader = texelFetch(colortex2, ivec2(gl_FragCoord.xy), 0);

  bool translucentCheck = TranslucentShader.a > 0.0 && TranslucentShader.a < 1.0;

  ////// --------------- AURORA

  #if AURORA_LOCATION > 0 && defined OVERWORLD_SHADER
    if (WsunVec.y < 0.0 && temporallyFilteredVL.a > 0.001 && VLBehindTranslucents.a > 0.001 && isSkyTranslucent
      #if AURORA_LOCATION < 2
        && auroraAmount > 0.001
      #endif
      #ifdef AURORA_MOON
        && WmoonVec.y < 0.1
      #endif
      #if AURORA_CHANCE < 100
        && hash_aurora(float(worldDay)) <= 0.01 * float(AURORA_CHANCE)
      #endif
      )
      {
      vec3 aurora = 0.0875*aurora(playerPos_normalized, 21, blueNoise(), WmoonVec.y, WsunVec.y);

      color += aurora;
    }
  #endif

  // ensure that bloomy fog mask in this VLBehindTranslucents.a does not darken outside of glass areas.
  if(translucentCheck) color.rgb = color.rgb * VLBehindTranslucents.a + VLBehindTranslucents.rgb;
  // to avoid bloomy fog applying to the surface of water, and the clouds, swap between high and low quality VL buffers.
  bloomyFogMult *= isWater ? temporallyFilteredVL.a * 0.75 + 0.25 : (TranslucentShader.a < 0.9995 ? VLBehindTranslucents.a * 0.75 + 0.25 : 1.0);

  // blend border fog. be sure to blend before and after forward rendered color blends.
  #if defined BorderFog && defined OVERWORLD_SHADER
    float borderFogDensity = getBorderFogDensity(linearDistance_cylinder, playerPos_normalized, isSky);
    vec4 borderFog;

    #if !defined SKY_GROUND
      borderFog.rgb = skyFromTex(playerPos_normalized, colortex4)/1200.0 * Sky_Brightness;
    #else
      borderFog.rgb = skyGroundColSSBO / 1200.0 * Sky_Brightness;
    #endif
    borderFog.a = borderFogDensity;
    
    #if !defined DISTANT_HORIZONS && !defined VOXY
      if(!isWater) color = mix(color, borderFog.rgb, getBorderFogDensity(linearDistance_cylinder_alt, normalize(playerPos_alt), z2 >= 1.0 || !translucentCheck));
    #endif
  #else
    vec4 borderFog = vec4(0.0);
  #endif

  // apply block breaking effect.
  bool isBlockBreaking = data.a > 0.99;
  if(albedo.a > 0.01 && !isWater && !isEntity && isBlockBreaking && !hand) color = mix(color*6.0, color, luma(albedo.rgb)) * albedo.rgb;
  
  // apply multiplicative color blend for glass n stuff
  #ifdef Glass_Tint
    if(
      #ifndef BIOME_TINT_WATER
      !isWater &&
      #endif
      translucentCheck && !isBlockBreaking) color *= mix(normalize(albedo.rgb+1e-7), vec3(1.0), max(borderFog.a, min(max(0.1-albedo.a,0.0) * 10.0,1.0))) ;
  #endif

  // blend forward rendered programs onto the color.
  blendForwardRendering(color, TranslucentShader);

  #if defined BorderFog && defined OVERWORLD_SHADER
    color = mix(color, borderFog.rgb, borderFogDensity);
  #endif
  
  // tweaks to VL for nametag rendering
	#if defined IS_IRIS
    temporallyFilteredVL.a = min(temporallyFilteredVL.a + (1.0-nametagbackground),1.0);
    temporallyFilteredVL.rgb *= nametagbackground;
  #endif

  // blend all fog types. volumetric fog, volumetric clouds, distance based fogs for lava, powdered snow, blindness, and darkness.
  blendAllFogTypes(color, bloomyFogMult, temporallyFilteredVL, linearDistance, playerPos_normalized, cameraPosition, isSky, isLightning);

  ////// --------------- RAINBOW

  #if RAINBOW > 0  && defined OVERWORLD_SHADER
    #if RAINBOW > 1 
      float rainbowAmount = 1.0;
    #endif

    float cosAngle = dot(-WsunVec, playerPos_normalized);
    if (isEyeInWater == 0 && rainbowAmount > 0.0 && cosAngle < 0.7431448 && cosAngle > 0.7071068) {
      #if defined DISTANT_HORIZONS || defined VOXY
        float clippingDistance = dhVoxyFarPlane;
      #else
        float clippingDistance = 4.0 * far;
      #endif
      if (RAINBOW_DISTANCE > 0.99999*clippingDistance) {
        if (linearDistance > 0.99999*clippingDistance) linearDistance = 1.1 * RAINBOW_DISTANCE; // allow rainbow distances greater than clipping distance
      }

      float angleFromSun = degrees(acos(cosAngle));
      float rainbowHue = 1.0 - smoothstep(41.4, 44.0, angleFromSun); // remove the red at the bottom
      vec3 rainbowColor = HsvToRgb(vec3(rainbowHue, 1.0, RAINBOW_BRIGHTNESS)) * smoothstep(42.0, 43.0, angleFromSun) * smoothstep(44.0, 43.0, angleFromSun);

      rainbowColor *= smoothstep(RAINBOW_DISTANCE*0.9, RAINBOW_DISTANCE*1.1, linearDistance) * smoothstep(0.025, 0.1, sunElevation);

      #if RAINBOW < 2
        rainbowColor *= rainbowAmount * (1.0 - rainStrength); 
      #endif

      #ifndef RAINBOW_ONLY_BELOW_CLOUDS
        rainbowColor *= smoothstep(CloudLayer0_height+CloudLayer0_tallness, CloudLayer0_height, playerPos_normalized.y*RAINBOW_DISTANCE+cameraPosition.y);
      #else
        rainbowColor = mix(rainbowColor*temporallyFilteredVL.a, rainbowColor, smoothstep(CloudLayer0_height+CloudLayer0_tallness, CloudLayer0_height, playerPos_normalized.y*RAINBOW_DISTANCE+cameraPosition.y));
      #endif

      color += rainbowColor * (1.0 - caveDetection);
    } 
  #endif

  // (bloomy) rain effect
  #ifdef OVERWORLD_SHADER
    #if RAIN_MODE == 0 // brighten the color behind
      float rainDrops = texelFetch(colortex9,ivec2(texcoord/texelSize),0).r;
      if(hand) rainDrops *= (1.0-TranslucentShader.a);

      if(rainDrops > 0.01) {
        bloomyFogMult *= clamp(1.0 - pow(rainDrops*5.0,2),0.0,1.0);
        color.rgb += color.rgb * RAIN_BRIGHTNESS * rainDrops;
      }
    #else // add albedo of weather particle
      vec4 rainDrops = texelFetch(colortex9,ivec2(texcoord/texelSize),0);
      rainDrops = vec4(decodeVec2(rainDrops.x), decodeVec2(rainDrops.y));
      if(hand) rainDrops.a *= (1.0-TranslucentShader.a);

      if(rainDrops.a > 0.01) {
        bloomyFogMult *= clamp(1.0 - pow(rainDrops.a*5.0,2),0.0,1.0);
        color.rgb += RAIN_BRIGHTNESS * rainDrops.rgb * rainDrops.a;
      }
    #endif
  #endif

////// --------------- FINALIZE
  #ifdef display_LUT
      float zoomLevel = 2.0;
      vec3 thingy = texelFetch(colortex4,ivec2(gl_FragCoord.xy/zoomLevel),0).rgb /1200.0;

      if(luma(thingy) > 0.0){
        color.rgb =  thingy;
        bloomyFogMult = 1.0;
      }

    #if defined OVERWORLD_SHADER
      if( hideGUI == 1) color.rgb = skyCloudsFromTex(playerPos_normalized, colortex4).rgb/1200.0;
    #else
      if( hideGUI == 1) color.rgb = volumetricsFromTex(playerPos_normalized, colortex4, 0.0).rgb/1200.0;
    #endif

  #endif
  gl_FragData[0] = vec4(bloomyFogMult,0.0,0.0,1.0); // pass fog alpha so bloom can do bloomy fog
  gl_FragData[1].rgb = clamp(color.rgb, 0.0,68000.0);

  // gl_FragData[1].rgb =  vec3(tangentNormals.xy,0.0) * 0.1  ;
  // gl_FragData[1].rgb =  vec3(1.0) * ld(    (data.a > 0.0 ? data.a : texture(depthtex0, texcoord).x   )              )   ;
  // gl_FragData[1].rgb = gl_FragData[1].rgb * (1.0-TranslucentShader.a) + TranslucentShader.rgb*10.0;
  // gl_FragData[1].rgb = 1-(texcoord.x > 0.5 ? vec3(TranslucentShader.a) : vec3(data.a));

}