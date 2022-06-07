# Powerpoint add slide howto

- copy all the constant stuff over
- for slide1 ONLY replace the image name
- for all other slides, derive from slide1.xml and .xml.rels
- copy all the mods over, in modified version

## docProps/app.xml

- Change number of slides:
  - from `<Slides>1`
  - to `<Slides>n`
  - replace `$NUM_SLIDES`

## ppt/_rels/presentation.xml.rels

- Add a new <Relationship> like for slide1 with a new Id `"rId{ 11 + n }"`
- replace `$RELATIONSHIPS`

```xml
<Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
```

## ppt/slides/slide[1].xml -> slide[n].xml

- Change `id="4" name="Grafik 4"`
  - to `id="{n}" name="Grafik {3 + n}descr="slides generated image {n}"`
  - replace ==$GRAPHIC_ID==
- Change `<a16 ... id={}` to a new guid
  - replace ==$GUID==
  - 6A92AC38-201A-B559-9037-63C6F3D7798E
- Change `<p14 ... val=""` to a new decimal id
  - replace ==$ID==
  - 1577499883

## ppt/slides/_rels/slide[n].xml.rels

- Just copy and adjust the target path to the image -> rename to `image{n}.png`
  - replace ==$IMG_NAME==

## ppt/presentation.xml

- Add new `<p:sldId id="{ 255 + n }" r:id="rId{ 11 + n }" ...`
  - replace ==$SLIDE_IDS==

## [Content_Types].xml

- Add new tag for the new slides
  - replace ==$SLIDES==

```xml
<Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
```
