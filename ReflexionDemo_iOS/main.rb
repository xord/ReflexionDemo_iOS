require 'reflexion/include'

y = 0

draw do
    stroke :white
    lines *(0..200).map {|x|
        xx = x * 5
        yy = 200 + Rays.perlin(x / 10.0, y / 50.0) * 100
        [xx, yy]
    }
    y += 1
end
