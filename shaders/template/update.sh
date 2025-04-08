#!/bin/bash

./potater item   '../item.properties'   '../lib/items.glsl'    -t './item.properties'
./potater block  '../block.properties'  '../lib/blocks.glsl'   -t './block.properties'
./potater entity '../entity.properties' '../lib/entities.glsl' -t './entity.properties'
