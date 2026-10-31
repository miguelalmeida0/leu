# Leu web design tokens

`web/src/tokens.css` owns the existing palette, Gabarito/Literata families, type scale, spacing and dimensions. `brand.css` applies semantic roles across routes. Screen styles own composition, not separate brand scales.

| Role | Token | Use |
|---|---|---|
| Page title | text-display | Home, Library, Notes, Explore, Study and Trails, including empty states |
| Body | text-body | UI explanations and descriptions |
| Control | text-control | Buttons, fields and segmented controls |
| Supporting text | text-sm / text-caption | Metadata and compact labels |
| Reading | reading-size / reading-leading | Rebuilt document prose; original PDFs retain source typography |
| Hit target | control-height | 44px minimum primary controls |
| Layout | page-gutter / content-width | Responsive shared page bounds |
| Spacing | space-1 through space-16 | 4px base scale |

Keep existing color contrast and visible keyboard focus. Home always plays while visible, as explicitly requested by the owner; other illustrations and interface transitions still honor reduced motion. Hidden tabs and offscreen canvases sleep. Reader uses the dynamic viewport and a flex shell, with separate content scrolling and a reserved listening footer.
