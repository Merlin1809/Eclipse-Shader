
#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"
#include "/lib/bokeh.glsl"
#include "/lib/blocks.glsl"
#include "/lib/entities.glsl"
#include "/lib/items.glsl"

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/


#ifdef HAND
#undef POM
#endif

#ifndef MC_NORMAL_MAP
#undef POM
#endif

#ifdef POM
#define MC_NORMAL_MAP
#endif


varying vec4 color;
varying float VanillaAO;

varying vec4 lmtexcoord;
varying vec4 normalMat;

// #ifdef POM
	varying vec4 vtexcoordam; // .st for add, .pq for mul
	varying vec4 vtexcoord;
// #endif

#ifdef MC_NORMAL_MAP
	varying vec4 tangent;
	attribute vec4 at_tangent;
	varying vec3 FlatNormals;
#endif

uniform float frameTimeCounter;
const float PI48 = 150.796447372*WAVY_SPEED;
float pi2wt = PI48*frameTimeCounter;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform int blockEntityId;
uniform int entityId;
flat varying float blockID;

uniform int heldItemId;
uniform int heldItemId2;
flat varying float HELD_ITEM_BRIGHTNESS;



flat varying int NameTags;

uniform int frameCounter;
uniform float far;
uniform float aspectRatio;
uniform float viewHeight;
uniform float viewWidth;
uniform int hideGUI;
uniform float screenBrightness;
uniform int isEyeInWater;

flat varying float SSSAMOUNT;
flat varying float EMISSIVE;
flat varying int LIGHTNING;
flat varying int PORTAL;
flat varying int SIGN;

// in vec3 at_velocity;
// out vec3 velocity;

uniform float nightVision;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec2 texelSize;
uniform int framemod8;

#if defined HAND
uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;

float detectCameraMovement(){
	// simply get the difference of modelview matrices and cameraPosition across a frame.
	vec3 fakePos = vec3(0.5,0.5,0.0);
	vec3 hand_playerPos = mat3(gbufferModelViewInverse) * fakePos + (cameraPosition - previousCameraPosition);
	vec3 previousPosition = mat3(gbufferPreviousModelView) * hand_playerPos;
	float detectMovement = 1.0 - clamp(distance(previousPosition, fakePos)/texelSize.x,0.0,1.0);
	
	return detectMovement;
}
#endif

#include "/lib/TAA_jitter.glsl"


							
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),-viewSpacePosition.z);
}

vec2 calcWave(in vec3 pos) {

    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos),vec4(1.0,0.005,0.005,0.005)))*0.5+0.72)*0.013;
	vec2 ret = (sin(pi2wt*vec2(0.0063,0.0015)*4. - pos.xz + pos.y*0.05)+0.1)*magnitude;

    return ret;
}

vec3 calcMovePlants(in vec3 pos) {
    vec2 move1 = calcWave(pos );
	float move1y = -length(move1);
   return vec3(move1.x,move1y,move1.y)*5.*WAVY_STRENGTH;
}

vec3 calcWaveLeaves(in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5) {

    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos),vec4(1.0,0.005,0.005,0.005)))*0.5+0.72)*0.013;
	vec3 ret = (sin(pi2wt*vec3(0.0063,0.0224,0.0015)*1.5 - pos))*magnitude;

    return ret;
}

vec3 calcMoveLeaves(in vec3 pos, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5, in vec3 amp1, in vec3 amp2) {
    vec3 move1 = calcWaveLeaves(pos      , 0.0054, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
    return move1*5.*WAVY_STRENGTH;
}
vec3 srgbToLinear2(vec3 srgb){
    return mix(
        srgb / 12.92,
        pow(.947867 * srgb + .0521327, vec3(2.4) ),
        step( .04045, srgb )
    );
}
vec3 blackbody2(float Temp)
{
    float t = pow(Temp, -1.5);
    float lt = log(Temp);

    vec3 col = vec3(0.0);
         col.x = 220000.0 * t + 0.58039215686;
         col.y = 0.39231372549 * lt - 2.44549019608;
         col.y = Temp > 6500. ? 138039.215686 * t + 0.72156862745 : col.y;
         col.z = 0.76078431372 * lt - 5.68078431373;
         col = clamp(col,0.0,1.0);
         col = Temp < 1000. ? col * Temp * 0.001 : col;

    return srgbToLinear2(col);
}
// float luma(vec3 color) {
// 	return dot(color,vec3(0.21, 0.72, 0.07));
// }

#define SEASONS_VSH
#include "/lib/climate_settings.glsl"


uniform sampler2D noisetex;//depth
float densityAtPos(in vec3 pos){
	pos /= 18.;
	pos.xz *= 0.5;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	vec2 uv =  p.xz + f.xz + p.y * vec2(0.0,193.0);
	vec2 coord =  uv / 512.0;
	
	//The y channel has an offset to avoid using two textures fetches
	vec2 xy = texture2D(noisetex, coord).yx;

	return mix(xy.r,xy.g, f.y);
}
float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}
vec3 viewToWorld(vec3 viewPos) {
    vec4 pos;
    pos.xyz = viewPos;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	gl_Position = ftransform();

	#if defined ENTITIES && defined IS_IRIS
		// force out of frustum
		if (entityId == 1599) gl_Position.z -= 10000.0;
	#endif

	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;

    /////// ----- COLOR STUFF ----- ///////
	color = gl_Color;

	VanillaAO = 1.0 - clamp(color.a,0,1);
	if (color.a < 0.3) color.a = 1.0; // fix vanilla ao on some custom block models.
	


    /////// ----- RANDOM STUFF ----- ///////
	// gl_TextureMatrix[0] for animated things like charged creepers
	lmtexcoord.xy = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	// #ifdef POM
	vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texcoordminusmid = lmtexcoord.xy-midcoord;
	vtexcoordam.pq  = abs(texcoordminusmid)*2;
	vtexcoordam.st  = min(lmtexcoord.xy,midcoord-texcoordminusmid);
	vtexcoord.xy    = sign(texcoordminusmid)*0.5+0.5;
	// #endif


	vec2 lmcoord = gl_MultiTexCoord1.xy / 240.0; 
	lmtexcoord.zw = lmcoord;



	#ifdef MC_NORMAL_MAP
		vec3 alterTangent = at_tangent.rgb;

		tangent = vec4(normalize(gl_NormalMatrix * alterTangent.rgb), at_tangent.w);
	#endif

	normalMat = vec4(normalize(gl_NormalMatrix * gl_Normal), 1.0);
	
	FlatNormals = normalMat.xyz;

	blockID = mc_Entity.x ;

	if(blockID == BLOCK_GROUND_WAVING_VERTICAL || blockID == BLOCK_GRASS_SHORT || blockID == BLOCK_GRASS_TALL_LOWER || blockID == BLOCK_GRASS_TALL_UPPER ) normalMat.a = 0.60;


	PORTAL = 0;
	SIGN = 0;

	#if defined WORLD && !defined HAND
		if(blockEntityId == BLOCK_SIGN) SIGN = 1;

		if(blockEntityId == BLOCK_END_PORTAL || blockEntityId == 187) PORTAL = 1;
	#endif
	
	NameTags = 0;

#ifdef ENTITIES

	// disallow POM to work on item frames.
	if(entityId == ENTITY_ITEM_FRAME) SIGN = 1;


	// try and single out nametag text and then discard nametag background
	// if( dot(gl_Color.rgb, vec3(1.0/3.0)) < 1.0) NameTags = 1;
	// if(gl_Color.a < 1.0) NameTags = 1;
	// if(gl_Color.a >= 0.24 && gl_Color.a <= 0.25 ) gl_Position = vec4(10,10,10,1);
	if(entityId == ENTITY_SSS_MEDIUM || entityId == ENTITY_SSS_WEAK || entityId == ENTITY_PLAYER || entityId == 2468) normalMat.a = 0.45;
	
#endif

	if(mc_Entity.x == BLOCK_AIR_WAVING) normalMat.a = 0.55;

    /////// ----- EMISSIVE STUFF ----- ///////
		EMISSIVE = 0.0;
		LIGHTNING = 0;
	// if(NameTags > 0) EMISSIVE = 0.9;

	HELD_ITEM_BRIGHTNESS = 0.0;
	#ifdef Hand_Held_lights
		if(heldItemId > 999 || heldItemId2 > 999 ) HELD_ITEM_BRIGHTNESS = 0.9;
	#endif

	// normal block lightsources		
	if(mc_Entity.x >= 100 && mc_Entity.x < 300) EMISSIVE = 0.5;
	
	// special cases light lightning and beacon beams...	
	#ifdef ENTITIES
		if(entityId == ENTITY_LIGHTNING){
			LIGHTNING = 1;
			normalMat.a = 0.50;
		}
	#endif

    /////// ----- SSS STUFF ----- ///////
		SSSAMOUNT = 0.0;

#ifdef WORLD
    /////// ----- SSS ON BLOCKS ----- ///////
	// strong
	if (
		mc_Entity.x == BLOCK_SSS_STRONG || mc_Entity.x == BLOCK_SAPLING || mc_Entity.x == BLOCK_AIR_WAVING
	) {
		SSSAMOUNT = 1.0;
	}

	// medium
	if (
		mc_Entity.x == BLOCK_GROUND_WAVING || mc_Entity.x == BLOCK_GROUND_WAVING_VERTICAL
		|| mc_Entity.x == BLOCK_GRASS_SHORT || mc_Entity.x == BLOCK_GRASS_TALL_UPPER || mc_Entity.x == BLOCK_GRASS_TALL_LOWER
	) {
		SSSAMOUNT = 0.5;
	}
	if (
		mc_Entity.x == BLOCK_SSS_WEAK || mc_Entity.x == BLOCK_SSS_WEAK_2 ||
		mc_Entity.x == BLOCK_GLOW_LICHEN || mc_Entity.x == BLOCK_SNOW_LAYERS || mc_Entity.x == BLOCK_CARPET ||
		mc_Entity.x == BLOCK_AMETHYST_BUD_MEDIUM || mc_Entity.x == BLOCK_AMETHYST_BUD_LARGE || mc_Entity.x == BLOCK_AMETHYST_CLUSTER ||
		mc_Entity.x == BLOCK_BAMBOO || mc_Entity.x == BLOCK_SAPLING || mc_Entity.x == BLOCK_VINE
	) {
		SSSAMOUNT = 0.5;
	}
	
	// low
	#ifdef MISC_BLOCK_SSS
		if(
			mc_Entity.x == BLOCK_SSS_WEIRD || mc_Entity.x == BLOCK_GRASS
		){
			SSSAMOUNT = 0.5;
		}
	#endif

	#ifdef ENTITIES
		#ifdef MOB_SSS
		    /////// ----- SSS ON MOBS----- ///////
			// strong
			if(entityId == ENTITY_SSS_MEDIUM) SSSAMOUNT = 0.75;
	
			// medium
	
			// low
			if(entityId == ENTITY_SSS_WEAK || entityId == ENTITY_PLAYER) SSSAMOUNT = 0.4;
		#endif
	#endif

	#ifdef BLOCKENTITIES
	    /////// ----- SSS ON BLOCK ENTITIES----- ///////
		// strong

		// medium
		if(blockEntityId == BLOCK_SSS_WEAK_3) SSSAMOUNT = 0.4;

		// low

	#endif

   	vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;

	#ifdef WAVY_PLANTS
		// also use normal, so up/down facing geometry does not get detatched from its model parts.
		bool InterpolateFromBase = gl_MultiTexCoord0.t < max(mc_midTexCoord.t, abs(viewToWorld(FlatNormals).y));

		if(	
			(
				// these wave off of the ground. the area connected to the ground does not wave.
				(InterpolateFromBase && (mc_Entity.x == BLOCK_GRASS_TALL_LOWER || mc_Entity.x == BLOCK_GROUND_WAVING || mc_Entity.x == BLOCK_GRASS_SHORT || mc_Entity.x == BLOCK_SAPLING || mc_Entity.x == BLOCK_GROUND_WAVING_VERTICAL)) 

				// these wave off of the ceiling. the area connected to the ceiling does not wave.
				|| (!InterpolateFromBase && (mc_Entity.x == 17))

				// these wave off of the air. they wave uniformly
				|| (mc_Entity.x == BLOCK_GRASS_TALL_UPPER || mc_Entity.x == BLOCK_AIR_WAVING)

			) && abs(position.z) < 64.0
		){
			vec3 UnalteredWorldpos = worldpos;

			// apply displacement for waving plant blocks
			worldpos += calcMovePlants(worldpos + cameraPosition) * max(lmtexcoord.w,0.5);


			// apply displacement for waving leaf blocks specifically, overwriting the other waving mode. these wave off of the air. they wave uniformly
			if(mc_Entity.x == BLOCK_AIR_WAVING) worldpos = UnalteredWorldpos + calcMoveLeaves(worldpos + cameraPosition, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(1.0,0.2,1.0), vec3(0.5,0.1,0.5))*lmtexcoord.w;
		
		}
	#endif
	
	#ifdef PLANET_CURVATURE
		float curvature = length(worldpos) / (16*8);
		worldpos.y -= curvature*curvature * CURVATURE_AMOUNT;
	#endif

	position = mat3(gbufferModelView) * worldpos + gbufferModelView[3].xyz;
	
	// ensure hand/entities have the same transformations as the spidereyes and enchant glint programs.
	#if !defined ENTITIES && !defined HAND
		gl_Position = toClipSpace3(position);
	#endif
#endif

	#if defined Seasons && defined WORLD && !defined ENTITIES && !defined BLOCKENTITIES && !defined HAND
		YearCycleColor(color.rgb, gl_Color.rgb, mc_Entity.x == BLOCK_AIR_WAVING, true);
	#endif

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif
	#ifdef TAA
		#ifdef HAND
			// turn off jitter when camera moves.
			// this is to hide the jitter when the same happens for TAA blend factor and the jitter becomes visible during camera movement
			gl_Position.xy += (offsets[framemod8] * gl_Position.w*texelSize) * detectCameraMovement();
		#else	
			gl_Position.xy += offsets[framemod8] * gl_Position.w*texelSize;
		#endif
	#endif


#if DOF_QUALITY == 5
		vec2 jitter = clamp(jitter_offsets[frameCounter % 64], -1.0, 1.0);
		jitter = rotate(radians(float(frameCounter))) * jitter;
		jitter.y *= aspectRatio;
		jitter.x *= DOF_ANAMORPHIC_RATIO;

		#if MANUAL_FOCUS == -2
		float focusMul = 0;
		#elif MANUAL_FOCUS == -1
		float focusMul = gl_Position.z - mix(pow(512.0, screenBrightness), 512.0 * screenBrightness, 0.25);
		#else
		float focusMul = gl_Position.z - MANUAL_FOCUS;
		#endif

		vec2 totalOffset = (jitter * JITTER_STRENGTH) * focusMul * 1e-2;
		gl_Position.xy += hideGUI >= 1 ? totalOffset : vec2(0);
	#endif
}
