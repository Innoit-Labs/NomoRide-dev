const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');
const path = require('path');

const svgPath = path.join(__dirname, '..', 'assets', 'icons', 'app_icon.svg');
const outPath = path.join(__dirname, '..', 'assets', 'icons', 'app_icon.png');

const svg = fs.readFileSync(svgPath);
const resvg = new Resvg(svg, {
  fitTo: { mode: 'width', value: 1024 },
  background: '#000000',
});
const pngData = resvg.render();
fs.writeFileSync(outPath, pngData.asPng());
console.log('Wrote', outPath, pngData.width, 'x', pngData.height);
