# Editing Property Templates

Property templates are written in [iProperties](https://github.com/MikiP98/iProperties) format in order to make managing those properties much easier and to limit the size of those file.  
In order to process the properties, you need to instal the `iProperties` python package:
1. Make sure you have [Python](https://www.python.org/downloads/) installed on your PC, 
2. Now either:
    - Double click the `install_udpade_iProperties` file,  
      `.bat` on Widnows or `.sh` on other systems,
    - Install the pip package manually by running:  
      `pip install "git+https://github.com/MikiP98/iProperties.git"`   
      in your terminal

Now to process the templates into theirs final forms either:
- Use the runnable `process_all` file, `.bat` on Widnows or `.sh` on other systems
- Open the template folder in your terminal and run `iProperties` command manually.  
  You might want to run `iProperties --help` first or visit the [iProperties GitHub page](https://github.com/MikiP98/iProperties) to see all the available options


<br>

# Editing Colored Lighting
There are two ways to edit colored lighting (explained below).  
Either method will require editing the block.properties mappings.

## The Simple/Easy Way
New block IDs can be easily added to existing block/light mappings.

**Example:**  
You want to add coloured light support to `betternether:willow_torch`  
You need to check what existing entry has a color and strength similar to what willow torch would have.  
In this case it might be entry `242` made for `sea_lantern`  
You just need to add `betternether:willow_torch` after the existing `sea_lantern` block like this:  
`block.242=sea_lantern betternether:willow_torch`
If you want to later submit your mod support to Bliss for it to be officially added to Bliss, you need to sort the mods alphabecitly in separate lines.  
Here is an example of this for entry `242`:
```properties
block.242=sea_lantern \
 betternether:willow_torch \
 flying_stuff:celestium_block \
 humility-afm:jack_o_lantern_soul \
 mcwlights:sea_lantern_slab
```

## The Advanced Way
Completely new block/light mappings can also be added, but it will require working with some GLSL code.

TODO: expand and example
