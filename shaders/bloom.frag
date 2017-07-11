extern vec2 size;
extern number samples; // pixels per axis; higher = bigger glow, worse performance
extern number quality; // lower = smaller glow, better quality

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
{
    vec4 source = Texel(tex, tc);
    vec4 sum = vec4(0);
    number diff = (samples - 1) / 2;
    vec2 sizeFactor = vec2(1) / size * quality;

    for (number x = -diff; x <= diff; x++)
    {
        for (number y = -diff; y <= diff; y++)
        {
            vec2 offset = vec2(x, y) * sizeFactor;
            sum += Texel(tex, tc + offset);
        }
    }

    return ((sum / (samples * samples)) + source) * color;
}
