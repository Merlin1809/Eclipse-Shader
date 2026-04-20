#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

#include "/lib/SSBOs.glsl"

out DATA {
	vec4 pos;
	vec4 gcolor;
		
	vec4 normalMat;
	vec2 lightmapCoords;
	flat int isWater;

	mat4 normalmatrix;

	flat vec3 WsunVec;
	flat vec3 WsunVec2;
};

uniform sampler2D colortex4;

#ifdef OVERWORLD_SHADER
	#include "/lib/scene_controller.glsl"
#endif

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

uniform mat4 dhProjection;
uniform vec3 sunPosition;
uniform float sunElevation;

uniform vec2 texelSize;
uniform int framemod8;

#if DOF_QUALITY == 5
uniform int hideGUI;
uniform int frameCounter;
uniform float aspectRatio;
uniform float screenBrightness;
uniform float far;
#include "/lib/bokeh.glsl"
#endif


uniform int framemod4_DH;
#define DH_TAA_OVERRIDE
#include "/lib/TAA_jitter.glsl"



uniform vec3 cameraPosition;
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(dhProjection, viewSpacePosition),-viewSpacePosition.z);
}
                     
void main() {
    gl_Position = dhProjection * gl_ModelViewMatrix * gl_Vertex;
    
	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
   	
	vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;
	
	// worldpos.y -= length(worldpos)/(16*2);

	#ifdef PLANET_CURVATURE
		float curvature = length(worldpos.xz) / (16*8);
		worldpos.y -= curvature*curvature * CURVATURE_AMOUNT;
	#endif
	position = mat3(gbufferModelView) * worldpos + gbufferModelView[3].xyz;

	gl_Position = toClipSpace3(position);
	
	pos = gl_ModelViewMatrix * gl_Vertex;

	// vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
	
	

    isWater = 0;
	if (dhMaterialId == DH_BLOCK_WATER){
	    isWater = 1;
		
		// offset water to not look like a full cube
    	// vec3 worldpos = mat3(gbufferModelViewInverse) * position;// + gbufferModelViewInverse[3].xyz ;
		// worldpos.y -= 1.8/16.0;
    	// position = mat3(gbufferModelView) * worldpos;// + gbufferModelView[3].xyz;

	}

	// gl_Position = toClipSpace3(position);

	normalMat = vec4(mat3(gbufferModelView) * gl_Normal, 1.0);

    gcolor = gl_Color;
	lightmapCoords = gl_MultiTexCoord1.xy;
	lightmapCoords = lightmapCoords / (30.0 / 32.0) - (1.0 / 32.0);

	#ifdef CUSTOM_MOON_ROTATION
		vec3 WmoonVec = customMoonVecSSBO;

		#ifdef SMOOTH_SUN_ROTATION
			WsunVec = WsunVecSmooth;
		#else
			WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);
		#endif
		WsunVec2 = normalize(sunPosition);

		WsunVec = mix(WmoonVec, WsunVec, float(sunElevation > 1e-5));
		WsunVec2 = mix(normalize(mat3(gbufferModelView)*WmoonVec), WsunVec2, float(sunElevation > 1e-5));
	#else
		float lightSourceCheck = float(sunElevation > 1e-5)*2.0 - 1.0;
		#ifdef SMOOTH_SUN_ROTATION
			WsunVec = lightSourceCheck * WsunVecSmooth;
		#else
			WsunVec = lightSourceCheck * normalize(mat3(gbufferModelViewInverse) * sunPosition);
		#endif
		WsunVec2 = lightSourceCheck * normalize(sunPosition);
	#endif

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif
    #if defined TAA && defined DH_TAA_JITTER
		gl_Position.xy += offsets[framemod4_DH] * gl_Position.w*texelSize;
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