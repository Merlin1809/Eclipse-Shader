#ifdef IS_LPV_ENABLED
    vec3 GetHandLight(const in int itemId, const in vec3 playerPos, const in vec3 normal) {
        vec3 lightFinal = vec3(0.0);
        vec3 lightColor = vec3(0.0);
        float lightRange = 0.0;

        uvec2 blockData = texelFetch(texBlockData, itemId, 0).rg;
        vec4 lightColorRange = unpackUnorm4x8(blockData.r);
        lightColor = srgbToLinear(lightColorRange.rgb);
        lightRange = lightColorRange.a * 255.0;

        if (lightRange > 0.0) {
            float lightDist = length(playerPos);
            vec3 lightDir = playerPos / lightDist;
            float NoL = 1.0;//max(dot(normal, lightDir), 0.0);
            float falloff = pow(1.0 - lightDist / lightRange, 3.0);
            lightFinal = lightColor * NoL * max(falloff, 0.0);
        }

        return lightFinal;
    }
#endif

vec3 doBlockLightLighting(
    vec3 lightColor, float lightmap,
    vec3 playerPos, vec3 lpvPos
){
    lightmap = clamp(lightmap,0.0,1.0);

    float lightmapBrightspot = min(max(lightmap-0.7,0.0)*3.3333,1.0);
    lightmapBrightspot *= lightmapBrightspot*lightmapBrightspot;

    float lightmapLight = 1.0-sqrt(1.0-lightmap);
    lightmapLight *= lightmapLight;

    float lightmapCurve = mix(lightmapLight, 2.5, lightmapBrightspot);
    vec3 blockLight = lightmapCurve * lightColor;
    
    #if defined IS_LPV_ENABLED && defined MC_GL_EXT_shader_image_load_store
        vec4 lpvSample = SampleLpvLinear(lpvPos);
        #ifdef VANILLA_LIGHTMAP_MASK
            lpvSample.rgb *= lightmapCurve;
        #endif
        vec3 lpvBlockLight = GetLpvBlockLight(lpvSample);

        // create a smooth falloff at the edges of the voxel volume.
        float fadeLength = 10.0; // in meters
        vec3 cubicRadius = clamp( min(((LpvSize3-1.0) - lpvPos)/fadeLength,      lpvPos/fadeLength) ,0.0,1.0);
        float voxelRangeFalloff = cubicRadius.x*cubicRadius.y*cubicRadius.z;
        voxelRangeFalloff = 1.0 - pow(1.0-pow(voxelRangeFalloff,1.5),3.0);
        
        // outside the voxel volume, lerp to vanilla lighting as a fallback
        // blockLight = mix(blockLight, lpvSample.rgb, voxelRangeFalloff);
        
        // to fix optifine/continuity custom emissives, only allow the vanilla lightmap at high torch light levels.
        vec3 mix_lpvsample = mix(max(lpvSample.rgb, lightColor * 2.5 * min(max(lightmap-0.9,0.0)/(1.0-0.9),1.0)), lpvSample.rgb, clamp(dot(lpvSample.rgb,vec3(1.0)),0.0,1.0));
        blockLight = mix(blockLight, mix_lpvsample, voxelRangeFalloff);

        #ifdef Hand_Held_lights
            // create handheld lightsources
            const vec3 normal = vec3(0.0); // TODO

                if (heldItemId > 0)
                blockLight += GetHandLight(heldItemId, playerPos, normal);

                if (heldItemId2 > 0)
                blockLight += GetHandLight(heldItemId2, playerPos, normal);
        #endif
    #endif

    return blockLight * TORCH_AMOUNT;
}

vec3 doIndirectLighting(
    vec3 lightColor, vec3 minimumLightColor, float lightmap
){

    // float lightmapCurve = pow(1.0-pow(1.0-lightmap,2.0),2.0);
    // float lightmapCurve = lightmap*lightmap;
    float lightmapCurve = (pow(lightmap,15.0)*2.0 + lightmap*lightmap)/3.0; //make sure its 0.0-1.0

    vec3 indirectLight = lightColor * lightmapCurve * ambient_brightness; 

    // indirectLight = max(indirectLight, minimumLightColor * (MIN_LIGHT_AMOUNT * 0.02 * 0.2 + nightVision));
    indirectLight += minimumLightColor * (MIN_LIGHT_AMOUNT * 0.02 * 0.2 + nightVision*0.02);

    return indirectLight;
}

uniform float centerDepthSmooth;

#if defined VIVECRAFT
	uniform bool vivecraftIsVR;
	uniform vec3 vivecraftRelativeMainHandPos;
	uniform vec3 vivecraftRelativeOffHandPos;
	uniform mat4 vivecraftRelativeMainHandRot;
	uniform mat4 vivecraftRelativeOffHandRot;
#endif

vec3 calculateFlashlight(in vec2 texcoord, in vec3 viewPos, in vec3 albedo, in vec3 normal, out vec4 flashLightSpecularData, bool hand){

	// vec3 shiftedViewPos = viewPos + vec3(-0.25, 0.2, 0.0);
	// vec3 shiftedPlayerPos = mat3(gbufferModelViewInverse) * shiftedViewPos + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition) * 3.0;
	// shiftedViewPos = mat3(gbufferPreviousModelView) * shiftedPlayerPos + gbufferPreviousModelView[3].xyz;
	vec3 shiftedViewPos;
    vec3 shiftedPlayerPos;
	float forwardOffset;

    #ifdef VIVECRAFT
        if (vivecraftIsVR) {
	        forwardOffset = 0.0;
            shiftedPlayerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz + vivecraftRelativeMainHandPos;
            shiftedViewPos = shiftedPlayerPos * mat3(vivecraftRelativeMainHandRot);
        } else
    #endif
    {
	    forwardOffset = 0.5;
        shiftedViewPos = viewPos + vec3(-0.25, 0.2, 0.0);
        shiftedPlayerPos = mat3(gbufferModelViewInverse) * shiftedViewPos + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition) * 3.0;
        shiftedViewPos = mat3(gbufferPreviousModelView) * shiftedPlayerPos + gbufferPreviousModelView[3].xyz;
    }

    
    
    vec2 scaledViewPos = shiftedViewPos.xy / max(-shiftedViewPos.z - forwardOffset, 1e-7);
	float linearDistance = length(shiftedPlayerPos);
	float shiftedLinearDistance = length(scaledViewPos);

	float lightFalloff = 1.0 - clamp(1.0-linearDistance/FLASHLIGHT_RANGE, -0.999,1.0);
	lightFalloff = max(exp(-10.0 * FLASHLIGHT_BRIGHTNESS_FALLOFF_MULT * lightFalloff),0.0);

	#if defined FLASHLIGHT_SPECULAR && (defined DEFERRED_SPECULAR || defined FORWARD_SPECULAR)
		float flashLightSpecular = lightFalloff * exp2(-7.0*shiftedLinearDistance*shiftedLinearDistance) * FLASHLIGHT_BRIGHTNESS_MULT;
		flashLightSpecularData = vec4(normalize(shiftedPlayerPos), flashLightSpecular);	
	#endif

	float projectedCircle = clamp(1.0 - shiftedLinearDistance*FLASHLIGHT_SIZE,0.0,1.0);
	float lenseDirt = texture2D(noisetex, scaledViewPos * 0.2 + 0.1).b;
	float lenseShape = (pow(abs(pow(abs(projectedCircle-1.0),2.0)*2.0 - 0.5),2.0) + lenseDirt*0.2) * 10.0;
	
	float offsetNdotL = clamp(dot(-normal, normalize(shiftedPlayerPos)),0,1);
	vec3 flashlightDiffuse = vec3(1.0) * lightFalloff * offsetNdotL * pow(1.0-pow(1.0-projectedCircle,2),2) * lenseShape * FLASHLIGHT_BRIGHTNESS_MULT;
	
	if(hand){
		flashlightDiffuse = vec3(0.0);
		flashLightSpecularData = vec4(0.0);
	}

	#ifdef FLASHLIGHT_BOUNCED_INDIRECT
		float lightWidth = 1.0+linearDistance*3.0;
		vec3 pointPos = mat3(gbufferModelViewInverse) *  (toScreenSpace(vec3(texcoord, centerDepthSmooth)) + vec3(-0.25, 0.2, 0.0));
		float flashLightHitPoint = distance(pointPos, shiftedPlayerPos);

		float indirectFlashLight = exp(-10.0 * (1.0 - clamp(1.0-length(shiftedViewPos.xy)/lightWidth,0.0,1.0)) );
		indirectFlashLight *= pow(clamp(1.0-flashLightHitPoint/lightWidth,0,1),2.0);

		flashlightDiffuse += albedo/150.0 * indirectFlashLight * lightFalloff;
	#endif

	return flashlightDiffuse * vec3(FLASHLIGHT_R,FLASHLIGHT_G,FLASHLIGHT_B);
}
