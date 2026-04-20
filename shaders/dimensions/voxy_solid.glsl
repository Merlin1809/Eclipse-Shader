#define VOXY_PROGRAM

#include "/lib/settings.glsl"
#include "/lib/blocks.glsl"

#undef PER_BIOME_ENVIRONMENT
#undef TIMEOFDAYFOG
#define SEASONS_VSH
#include "/lib/climate_settings.glsl"

layout (location = 0) out vec4 gbuffer_data_0;
layout (location = 1) out vec4 gbuffer_data_1;

vec2 encodeNormal(vec3 n){
	n.xy = n.xy / dot(abs(n), vec3(1.0));
	n.xy = n.z <= 0.0 ? (1.0 - abs(n.yx)) * sign(n.xy) : n.xy;
    vec2 encn = clamp(n.xy * 0.5 + 0.5,-1.0,1.0);
	
    return encn;
}

//encoding by jodie
float encodeVec2(vec2 a){
    const vec2 constant1 = vec2( 1., 256.) / 65535.;
    vec2 temp = floor( a * 255. );
	return temp.x*constant1.x+temp.y*constant1.y;
}
float encodeVec2(float x,float y){
    return encodeVec2(vec2(x,y));
}

#if EMISSIVE_TYPE > 0
	#include "/lib/hsv.glsl"

	float getEmission(vec3 Albedo) {
		vec3 hsv = RgbToHsv(Albedo);
		float emissive = smoothstep(0.05, 0.15, hsv.y) * pow(hsv.z, 3.5);
		return emissive * 0.5;
	}
#endif

#ifdef VISUALIZE_LIGHTMAP
	#include "/lib/text_rendering.glsl"
#endif


void voxy_emitFragment(VoxyFragmentParameters parameters) {

    vec4 Albedo;

	vec3 color = parameters.tinting.rgb;

	int blockID = int(parameters.customId);

	#if defined Seasons
		YearCycleColor(color, parameters.tinting.rgb, blockID == BLOCK_AIR_WAVING, true);
	#endif

    Albedo.rgb = parameters.sampledColour.rgb * color;

    float SSSAMOUNT = 0.0;

	#if SSS_TYPE > 0 && defined VOXY_SSS
		/////// ----- SSS ON BLOCKS ----- ///////
		// strong
		if (
			blockID == BLOCK_SSS_STRONG || blockID == BLOCK_SSS_STRONG3 || blockID == BLOCK_AIR_WAVING || blockID == BLOCK_SSS_STRONG_2
		) {
			SSSAMOUNT = 1.0;
		}
		// medium
		else if (
			blockID == BLOCK_GROUND_WAVING || blockID == BLOCK_GROUND_WAVING_VERTICAL
			|| blockID == BLOCK_GRASS_SHORT || blockID == BLOCK_GRASS_TALL_UPPER || blockID == BLOCK_GRASS_TALL_LOWER
		) {
			SSSAMOUNT = 0.5;
		}
		else if (
			blockID == BLOCK_SSS_WEAK || blockID == BLOCK_CACTUS || blockID == BLOCK_SSS_WEAK_2 ||
			blockID == BLOCK_CELESTIUM || blockID == BLOCK_SNOW_LAYERS || blockID == BLOCK_CARPET ||
			blockID == BLOCK_AMETHYST_BUD_MEDIUM || blockID == BLOCK_AMETHYST_BUD_LARGE || blockID == BLOCK_AMETHYST_CLUSTER ||
			blockID == BLOCK_BAMBOO || blockID == BLOCK_SAPLING || blockID == BLOCK_VINE || blockID == BLOCK_VINE_OTHER
		) {
			SSSAMOUNT = 0.5;
		}
		
		// low
		#ifdef MISC_BLOCK_SSS
			else if(
				blockID == BLOCK_SSS_WEIRD || blockID == BLOCK_GRASS
			){
				SSSAMOUNT = 0.5;
			}
		#endif
	#endif

	float EMISSIVE = 0.0;

	#if EMISSIVE_TYPE > 0
		/////// ----- EMISSIVE STUFF ----- ///////

		// if(vNameTags > 0) EMISSIVE = 0.9;

		// normal block lightsources
		if(blockID >= 100 && blockID < 282) {
			EMISSIVE = 0.5;

			if(blockID == 266 || (blockID >= 276 && blockID <= 281)) EMISSIVE = 0.2; // sculk stuff

			else if(blockID == 195) EMISSIVE = 2.3; // glow lichen

			else if(blockID == 185) EMISSIVE = 1.5; // crying obsidian

			else if(blockID == 105) EMISSIVE = 2.0; // brewing stand
			
			else if(blockID == 236) EMISSIVE = 1.0; // respawn anchor

			else if(blockID == 101) EMISSIVE = 0.7; // large amethyst bud

			else if(blockID == 103) EMISSIVE = 1.0; // amethyst cluster

			else if(blockID == 244) EMISSIVE = 1.5; // soul fire
		}

		#if EMISSIVE_ORES > 0
			if(blockID == 502) EMISSIVE = EMISSIVE_ORES_STRENGTH;
		#endif

		#ifdef HARDCODED_EMISSIVES_APPROX
			EMISSIVE *= getEmission(Albedo.rgb);
		#endif
	#endif

    Albedo.a = 1.0;
	if(blockID == BLOCK_GROUND_WAVING_VERTICAL || blockID == BLOCK_GRASS_SHORT || blockID == BLOCK_GRASS_TALL_LOWER || blockID == BLOCK_GRASS_TALL_UPPER) Albedo.a = 0.60;
	else if(blockID == BLOCK_AIR_WAVING) Albedo.a = 0.55;

    vec3 normal = vec3(uint((parameters.face>>1)==2), uint((parameters.face>>1)==0), uint((parameters.face>>1)==1)) * (float(int(parameters.face)&1)*2-1);

	if (normal.z<=-0.9) normal.xy = vec2(-0.0000000000001);

	vec2 lightmap = parameters.lightMap;
	lightmap = lightmap / (30.0 / 32.0) - (1.0 / 32.0);

    vec4 data1 = clamp(vec4(encodeNormal(normal), lightmap), 0.0, 1.0);

	#ifdef VISUALIZE_LIGHTMAP
		beginText(ivec2(gl_FragCoord.xy/vec2(8.0, 8.0)), ivec2(0.45*viewWidth/8.0, 0.7*viewHeight/8.0));
		text.fgCol = vec4(1.0, 0.0, 0.0, 1.0);
		printVec2(lightmap);
		endText(Albedo.rgb);
	#endif

	Albedo = clamp(Albedo, 0.0, 1.0);
    
    gbuffer_data_0 = vec4(encodeVec2(Albedo.x,data1.x),	encodeVec2(Albedo.y,data1.y),	encodeVec2(Albedo.z,data1.z),	encodeVec2(data1.w,Albedo.w));

	EMISSIVE = clamp(EMISSIVE, 0.0, 0.99);
    gbuffer_data_1 = vec4(0.0, 0.0, SSSAMOUNT, EMISSIVE);

	vec4 otherData = clamp(vec4(normal * 0.5 + 0.5, 0.0), 0.0, 1.0);
	gbuffer_data_1 = clamp(gbuffer_data_1, 0.0, 1.0);

	gbuffer_data_1 = vec4(
		encodeVec2(gbuffer_data_1.x, otherData.x),
		encodeVec2(gbuffer_data_1.y, otherData.y),
		encodeVec2(gbuffer_data_1.z, otherData.z),
		encodeVec2(gbuffer_data_1.w, otherData.w)
	);

}