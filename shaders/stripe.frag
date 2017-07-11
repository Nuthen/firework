//extern vec2 size;
extern float height;

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
{
    //vec2 sizeFactor = vec2(1) / size;
    vec4 texturecolor = Texel(tex, tc) * color;

    if (mod(sc.y/2+1, height) <= 1) {
        texturecolor = vec4(1, 1, 1, 1);
    }

    return texturecolor;
}
