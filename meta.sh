#!/usr/bin/env bash

echo "const std = @import(\"std\");"
echo
echo "const PptxEmbed = struct { filename : [] const u8, content : [] const u8 };"
echo "pub const toCopy = std.ArrayList(*PptxEmbed);"
echo
for i in $(find pptx_template/const -type f) ; do
    fn=cpy_$(basename $i)
    varname=const_$(echo $fn | sed s/\\./_/g)
    destname=$(echo $i | sed 's/pptx_template\/const\///')
    echo "const $varname  = PptxEmbed { .filename = \"$destname\", .content = @embedFile(\"../$i\")};"
done
echo
echo "pub fn initToCopy() !*std.ArrayList(*PptxEmbed) {"
for i in $(find assets/pptx -type f) ; do
    fn=cpy_$(basename $i)
    varname=const_$(echo $fn | sed s/\\./_/g)
    echo "    try toCopy.append(&$varname);"
done
    echo "    return toCopy;"
echo "}"
echo
echo
for i in $(find pptx_template/variable -type f) ; do
    fn=cpy_$(basename $i)
    varname=mod_$(echo $fn | sed s/\\./_/g | sed s/\\[// | sed s/\\]//)
    destname=$(echo $i | sed 's/pptx_template\/variable\///')
    echo "const $varname  = PptxEmbed { .filename = \"$destname\", .content = @embedFile(\"../$i\")};"
done

# for i in $(find pptx_template -type f) ; do
#     fn=cpy_$(basename $i)
#     varname=mod_$(echo $fn | sed s/\\./_/g)
#     echo "toModify.append($varname);"
# done
