#version 430 compatibility
//#extension GL_ARB_shader_texture_lod : disable

#include "/lib/settings.glsl"

in flat int water;
in vec2 texcoord;

in float overdrawCull;
in vec4 gcolor;

uniform sampler2D gtexture;
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

    if(water > 0){   
        discard;
        return;
    }
    
    if(overdrawCull < 1.0){   
        discard;
        return;
    }
    
	gl_FragData[0] = texture(gtexture, texcoord.xy)*gcolor;
}
