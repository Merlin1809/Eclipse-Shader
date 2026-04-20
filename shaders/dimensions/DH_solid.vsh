#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

out DATA {
    vec4 localPos;
    vec4 vPos;
    vec4 gcolor;
    vec2 lightmapCoords;
    vec4 normalMat;
    flat float SSSAMOUNT;
    flat float EMISSIVE;
    flat int dh_material_id;
};

uniform float nightVision;

uniform vec2 texelSize;
uniform int framemod8;

uniform float far;

#if DOF_QUALITY == 5
uniform int hideGUI;
uniform int frameCounter;
uniform float aspectRatio;
uniform float screenBrightness;
#include "/lib/bokeh.glsl"
#endif

uniform int framemod4_DH;
#define DH_TAA_OVERRIDE
#include "/lib/TAA_jitter.glsl"



uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

uniform mat4 dhProjection;
uniform vec3 cameraPosition;

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(dhProjection, viewSpacePosition),-viewSpacePosition.z);
}

#define SEASONS_VSH
#define DH_SEASONS
#include "/lib/climate_settings.glsl"

void main() {

	// vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
   	// vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;
	// #ifdef PLANET_CURVATURE
	// 	float curvature = length(worldpos) / (16*8);
	// 	worldpos.y -= curvature*curvature * CURVATURE_AMOUNT;
	// #endif
	// position = mat3(gbufferModelView) * worldpos + gbufferModelView[3].xyz;

	// gl_Position = toClipSpace3(position);
	
    vPos = gl_Vertex;

    vec3 cameraOffset = fract(cameraPosition);
    vPos.xyz = floor(vPos.xyz + cameraOffset + 0.5) - cameraOffset;

    vec4 viewPos = gl_ModelViewMatrix * vPos;
	localPos = gbufferModelViewInverse * viewPos;

	#ifdef PLANET_CURVATURE
		vec4 worldPos = localPos;

		float curvature = length(worldPos.xz) / (16*8);
		worldPos.y -= curvature*curvature * CURVATURE_AMOUNT;

		worldPos = gbufferModelView * worldPos;

    	gl_Position = dhProjection * worldPos;
	#else
    	gl_Position = dhProjection * viewPos;
	#endif






	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif
    #if defined TAA && defined DH_TAA_JITTER
		gl_Position.xy += offsets[framemod4_DH] * gl_Position.w*texelSize;
	#endif
	
	lightmapCoords = gl_MultiTexCoord1.xy;
	lightmapCoords = lightmapCoords / (30.0 / 32.0) - (1.0 / 32.0);
    
    gcolor = gl_Color;
	

	EMISSIVE = 0.0;
	if(dhMaterialId == DH_BLOCK_ILLUMINATED || gl_MultiTexCoord1.x >= 0.95) EMISSIVE = 0.5;

	SSSAMOUNT = 0.0;
	#if defined DH_SUBSURFACE_SCATTERING
		if (dhMaterialId == DH_BLOCK_LEAVES) SSSAMOUNT = 1.0;
		if (dhMaterialId == DH_BLOCK_SNOW) SSSAMOUNT = 0.5;
	#endif

	// a mask for DH terrain in general.
	float MATERIALS = 0.65;

	normalMat = vec4(normalize(gl_NormalMatrix * gl_Normal), MATERIALS);
	dh_material_id = dhMaterialId;

	#if defined Seasons && defined OVERWORLD_SHADER
		YearCycleColor(gcolor.rgb, gl_Color.rgb, dhMaterialId == DH_BLOCK_LEAVES, dhMaterialId == DH_BLOCK_GRASS);
	#endif

	#if DOF_QUALITY == 5
		vec2 jitter = clamp(jitter_offsets[frameCounter % 64], -1.0, 1.0);
		jitter = rotate(radians(float(frameCounter))) * jitter;
		jitter.y *= aspectRatio;
		jitter.x *= DOF_ANAMORPHIC_RATIO;

		#if MANUAL_FOCUS == -2
		float focusMul = 0;
		#elif MANUAL_FOCUS == -1
		float focusMul = gl_Position.z + (far / 3.0) - mix(pow(512.0, screenBrightness), 512.0 * screenBrightness, 0.25);
		#else
		float focusMul = gl_Position.z + (far / 3.0) - MANUAL_FOCUS;
		#endif

		vec2 totalOffset = (jitter * JITTER_STRENGTH) * focusMul * 1e-2;
		gl_Position.xy += hideGUI >= 1 ? totalOffset : vec2(0);
	#endif
}