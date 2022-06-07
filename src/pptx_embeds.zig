const std = @import("std");

const PptxEmbed = struct { filename: []const u8, content: []const u8 };
const PptxEmbedList = std.ArrayList(*const PptxEmbed);
var toCopy: ?PptxEmbedList = null;

const const_cpy_core_xml = PptxEmbed{ .filename = "docProps/core.xml", .content = @embedFile("../assets/pptx/docProps/core.xml") };
const const_cpy_thumbnail_jpeg = PptxEmbed{ .filename = "docProps/thumbnail.jpeg", .content = @embedFile("../assets/pptx/docProps/thumbnail.jpeg") };
const const_cpy_custom_xml = PptxEmbed{ .filename = "docProps/custom.xml", .content = @embedFile("../assets/pptx/docProps/custom.xml") };
const const_cpy__rels = PptxEmbed{ .filename = "_rels/.rels", .content = @embedFile("../assets/pptx/_rels/.rels") };
const const_cpy_presProps_xml = PptxEmbed{ .filename = "ppt/presProps.xml", .content = @embedFile("../assets/pptx/ppt/presProps.xml") };
const const_cpy_theme1_xml = PptxEmbed{ .filename = "ppt/theme/theme1.xml", .content = @embedFile("../assets/pptx/ppt/theme/theme1.xml") };
const const_cpy_image1_png = PptxEmbed{ .filename = "ppt/media/image1.png", .content = @embedFile("../assets/pptx/ppt/media/image1.png") };
const const_cpy_slideLayout2_xml = PptxEmbed{ .filename = "ppt/slideLayouts/slideLayout2.xml", .content = @embedFile("../assets/pptx/ppt/slideLayouts/slideLayout2.xml") };
const const_cpy_slideLayout1_xml_rels = PptxEmbed{ .filename = "ppt/slideLayouts/_rels/slideLayout1.xml.rels", .content = @embedFile("../assets/pptx/ppt/slideLayouts/_rels/slideLayout1.xml.rels") };
const const_cpy_slideLayout9_xml_rels = PptxEmbed{ .filename = "ppt/slideLayouts/_rels/slideLayout9.xml.rels", .content = @embedFile("../assets/pptx/ppt/slideLayouts/_rels/slideLayout9.xml.rels") };
const const_cpy_slideLayout7_xml_rels = PptxEmbed{ .filename = "ppt/slideLayouts/_rels/slideLayout7.xml.rels", .content = @embedFile("../assets/pptx/ppt/slideLayouts/_rels/slideLayout7.xml.rels") };
const const_cpy_slideLayout8_xml_rels = PptxEmbed{ .filename = "ppt/slideLayouts/_rels/slideLayout8.xml.rels", .content = @embedFile("../assets/pptx/ppt/slideLayouts/_rels/slideLayout8.xml.rels") };
const const_cpy_slideLayout11_xml_rels = PptxEmbed{ .filename = "ppt/slideLayouts/_rels/slideLayout11.xml.rels", .content = @embedFile("../assets/pptx/ppt/slideLayouts/_rels/slideLayout11.xml.rels") };
const const_cpy_slideLayout4_xml_rels = PptxEmbed{ .filename = "ppt/slideLayouts/_rels/slideLayout4.xml.rels", .content = @embedFile("../assets/pptx/ppt/slideLayouts/_rels/slideLayout4.xml.rels") };
const const_cpy_slideLayout10_xml_rels = PptxEmbed{ .filename = "ppt/slideLayouts/_rels/slideLayout10.xml.rels", .content = @embedFile("../assets/pptx/ppt/slideLayouts/_rels/slideLayout10.xml.rels") };
const const_cpy_slideLayout6_xml_rels = PptxEmbed{ .filename = "ppt/slideLayouts/_rels/slideLayout6.xml.rels", .content = @embedFile("../assets/pptx/ppt/slideLayouts/_rels/slideLayout6.xml.rels") };
const const_cpy_slideLayout2_xml_rels = PptxEmbed{ .filename = "ppt/slideLayouts/_rels/slideLayout2.xml.rels", .content = @embedFile("../assets/pptx/ppt/slideLayouts/_rels/slideLayout2.xml.rels") };
const const_cpy_slideLayout5_xml_rels = PptxEmbed{ .filename = "ppt/slideLayouts/_rels/slideLayout5.xml.rels", .content = @embedFile("../assets/pptx/ppt/slideLayouts/_rels/slideLayout5.xml.rels") };
const const_cpy_slideLayout3_xml_rels = PptxEmbed{ .filename = "ppt/slideLayouts/_rels/slideLayout3.xml.rels", .content = @embedFile("../assets/pptx/ppt/slideLayouts/_rels/slideLayout3.xml.rels") };
const const_cpy_slideLayout11_xml = PptxEmbed{ .filename = "ppt/slideLayouts/slideLayout11.xml", .content = @embedFile("../assets/pptx/ppt/slideLayouts/slideLayout11.xml") };
const const_cpy_slideLayout3_xml = PptxEmbed{ .filename = "ppt/slideLayouts/slideLayout3.xml", .content = @embedFile("../assets/pptx/ppt/slideLayouts/slideLayout3.xml") };
const const_cpy_slideLayout8_xml = PptxEmbed{ .filename = "ppt/slideLayouts/slideLayout8.xml", .content = @embedFile("../assets/pptx/ppt/slideLayouts/slideLayout8.xml") };
const const_cpy_slideLayout6_xml = PptxEmbed{ .filename = "ppt/slideLayouts/slideLayout6.xml", .content = @embedFile("../assets/pptx/ppt/slideLayouts/slideLayout6.xml") };
const const_cpy_slideLayout4_xml = PptxEmbed{ .filename = "ppt/slideLayouts/slideLayout4.xml", .content = @embedFile("../assets/pptx/ppt/slideLayouts/slideLayout4.xml") };
const const_cpy_slideLayout10_xml = PptxEmbed{ .filename = "ppt/slideLayouts/slideLayout10.xml", .content = @embedFile("../assets/pptx/ppt/slideLayouts/slideLayout10.xml") };
const const_cpy_slideLayout9_xml = PptxEmbed{ .filename = "ppt/slideLayouts/slideLayout9.xml", .content = @embedFile("../assets/pptx/ppt/slideLayouts/slideLayout9.xml") };
const const_cpy_slideLayout7_xml = PptxEmbed{ .filename = "ppt/slideLayouts/slideLayout7.xml", .content = @embedFile("../assets/pptx/ppt/slideLayouts/slideLayout7.xml") };
const const_cpy_slideLayout1_xml = PptxEmbed{ .filename = "ppt/slideLayouts/slideLayout1.xml", .content = @embedFile("../assets/pptx/ppt/slideLayouts/slideLayout1.xml") };
const const_cpy_slideLayout5_xml = PptxEmbed{ .filename = "ppt/slideLayouts/slideLayout5.xml", .content = @embedFile("../assets/pptx/ppt/slideLayouts/slideLayout5.xml") };
const const_cpy_tableStyles_xml = PptxEmbed{ .filename = "ppt/tableStyles.xml", .content = @embedFile("../assets/pptx/ppt/tableStyles.xml") };
const const_cpy_viewProps_xml = PptxEmbed{ .filename = "ppt/viewProps.xml", .content = @embedFile("../assets/pptx/ppt/viewProps.xml") };
const const_cpy_slideMaster1_xml_rels = PptxEmbed{ .filename = "ppt/slideMasters/_rels/slideMaster1.xml.rels", .content = @embedFile("../assets/pptx/ppt/slideMasters/_rels/slideMaster1.xml.rels") };
const const_cpy_slideMaster1_xml = PptxEmbed{ .filename = "ppt/slideMasters/slideMaster1.xml", .content = @embedFile("../assets/pptx/ppt/slideMasters/slideMaster1.xml") };
const const_cpy_revisionInfo_xml = PptxEmbed{ .filename = "ppt/revisionInfo.xml", .content = @embedFile("../assets/pptx/ppt/revisionInfo.xml") };
const const_cpy_item2_xml_rels = PptxEmbed{ .filename = "customXml/_rels/item2.xml.rels", .content = @embedFile("../assets/pptx/customXml/_rels/item2.xml.rels") };
const const_cpy_item3_xml_rels = PptxEmbed{ .filename = "customXml/_rels/item3.xml.rels", .content = @embedFile("../assets/pptx/customXml/_rels/item3.xml.rels") };
const const_cpy_item1_xml_rels = PptxEmbed{ .filename = "customXml/_rels/item1.xml.rels", .content = @embedFile("../assets/pptx/customXml/_rels/item1.xml.rels") };
const const_cpy_item2_xml = PptxEmbed{ .filename = "customXml/item2.xml", .content = @embedFile("../assets/pptx/customXml/item2.xml") };
const const_cpy_item1_xml = PptxEmbed{ .filename = "customXml/item1.xml", .content = @embedFile("../assets/pptx/customXml/item1.xml") };
const const_cpy_item3_xml = PptxEmbed{ .filename = "customXml/item3.xml", .content = @embedFile("../assets/pptx/customXml/item3.xml") };
const const_cpy_itemProps3_xml = PptxEmbed{ .filename = "customXml/itemProps3.xml", .content = @embedFile("../assets/pptx/customXml/itemProps3.xml") };
const const_cpy_itemProps2_xml = PptxEmbed{ .filename = "customXml/itemProps2.xml", .content = @embedFile("../assets/pptx/customXml/itemProps2.xml") };
const const_cpy_itemProps1_xml = PptxEmbed{ .filename = "customXml/itemProps1.xml", .content = @embedFile("../assets/pptx/customXml/itemProps1.xml") };

pub fn initToCopy(allocator: std.mem.Allocator) !*PptxEmbedList {
    if (toCopy == null) {
        toCopy = PptxEmbedList.init(allocator);
    }
    if (toCopy) |*cp| {
        try cp.append(&const_cpy_core_xml);
        try cp.append(&const_cpy_thumbnail_jpeg);
        try cp.append(&const_cpy_custom_xml);
        try cp.append(&const_cpy__rels);
        try cp.append(&const_cpy_presProps_xml);
        try cp.append(&const_cpy_theme1_xml);
        try cp.append(&const_cpy_image1_png);
        try cp.append(&const_cpy_slideLayout2_xml);
        try cp.append(&const_cpy_slideLayout1_xml_rels);
        try cp.append(&const_cpy_slideLayout9_xml_rels);
        try cp.append(&const_cpy_slideLayout7_xml_rels);
        try cp.append(&const_cpy_slideLayout8_xml_rels);
        try cp.append(&const_cpy_slideLayout11_xml_rels);
        try cp.append(&const_cpy_slideLayout4_xml_rels);
        try cp.append(&const_cpy_slideLayout10_xml_rels);
        try cp.append(&const_cpy_slideLayout6_xml_rels);
        try cp.append(&const_cpy_slideLayout2_xml_rels);
        try cp.append(&const_cpy_slideLayout5_xml_rels);
        try cp.append(&const_cpy_slideLayout3_xml_rels);
        try cp.append(&const_cpy_slideLayout11_xml);
        try cp.append(&const_cpy_slideLayout3_xml);
        try cp.append(&const_cpy_slideLayout8_xml);
        try cp.append(&const_cpy_slideLayout6_xml);
        try cp.append(&const_cpy_slideLayout4_xml);
        try cp.append(&const_cpy_slideLayout10_xml);
        try cp.append(&const_cpy_slideLayout9_xml);
        try cp.append(&const_cpy_slideLayout7_xml);
        try cp.append(&const_cpy_slideLayout1_xml);
        try cp.append(&const_cpy_slideLayout5_xml);
        try cp.append(&const_cpy_tableStyles_xml);
        try cp.append(&const_cpy_viewProps_xml);
        try cp.append(&const_cpy_slideMaster1_xml_rels);
        try cp.append(&const_cpy_slideMaster1_xml);
        try cp.append(&const_cpy_revisionInfo_xml);
        try cp.append(&const_cpy_item2_xml_rels);
        try cp.append(&const_cpy_item3_xml_rels);
        try cp.append(&const_cpy_item1_xml_rels);
        try cp.append(&const_cpy_item2_xml);
        try cp.append(&const_cpy_item1_xml);
        try cp.append(&const_cpy_item3_xml);
        try cp.append(&const_cpy_itemProps3_xml);
        try cp.append(&const_cpy_itemProps2_xml);
        try cp.append(&const_cpy_itemProps1_xml);
    }
    return &toCopy.?;
}

const mod_cpy_app_xml = PptxEmbed{ .filename = "docProps/app.xml", .content = @embedFile("pptx_template/docProps/app.xml") };
const mod_cpy_Content_Types_xml = PptxEmbed{ .filename = "[Content_Types].xml", .content = @embedFile("pptx_template/[Content_Types].xml") };
const mod_cpy_presentation_xml_rels = PptxEmbed{ .filename = "ppt/_rels/presentation.xml.rels", .content = @embedFile("pptx_template/ppt/_rels/presentation.xml.rels") };
const mod_cpy_slide1_xml_rels = PptxEmbed{ .filename = "ppt/slides/_rels/slide1.xml.rels", .content = @embedFile("pptx_template/ppt/slides/_rels/slide1.xml.rels") };
const mod_cpy_slide1_xml = PptxEmbed{ .filename = "ppt/slides/slide1.xml", .content = @embedFile("pptx_template/ppt/slides/slide1.xml") };
const mod_cpy_presentation_xml = PptxEmbed{ .filename = "ppt/presentation.xml", .content = @embedFile("pptx_template/ppt/presentation.xml") };
