// Shared node-link diagram builders for the crossmap explorer's OJS pages
// (02-crossmap-explorer.qmd, 03-country-variants.qmd, 04-composed-overview.qmd).
// d3 is passed in rather than required here, since each page already does
// its own `d3 = require("d3@7")` and OJS resolves that per-notebook.

export function evenY(n, height, pad = 18) {
  if (n <= 1) return [height / 2];
  const usable = height - 2 * pad;
  return d3Range(n).map(i => pad + (i * usable) / (n - 1));
}

// avoid importing d3 just for d3.range -- trivial to inline
function d3Range(n) {
  return Array.from({ length: n }, (_, i) => i);
}

// 3-column diagram: isiccomb -> isic member -> isic.3 parent. Used by (c)
// and (c') -- per-country-year components where the isic intermediate is
// still meaningful to show. Target-node shading is by in-degree (# of isic
// children feeding a given isic.3 parent), against a fixed dataset-wide
// domain (maxIsic3Indegree) so "how dark" means the same thing everywhere.
export function buildCrossmapNodeLink3Col(d3, edgesForCode, {
  maxIsic3Indegree,
  width = 380,
  fontSize = 10,
  rowHeight = 20,
  padY = 36,
  minHeight = 90,
  margin = 54,
} = {}) {
  const isiccomb = edgesForCode[0].isiccomb;

  const col0 = [isiccomb];

  const col1 = Array.from(new Set(edgesForCode.map(d => d.isic))).sort((a, b) => {
    const pa = edgesForCode.find(d => d.isic === a).isic3;
    const pb = edgesForCode.find(d => d.isic === b).isic3;
    return d3.ascending(pa, pb) || d3.ascending(a, b);
  });

  const inDeg2 = d3.rollup(edgesForCode, v => new Set(v.map(d => d.isic)).size, d => d.isic3);
  const col2 = Array.from(new Set(edgesForCode.map(d => d.isic3)))
    .sort((a, b) => d3.descending(inDeg2.get(a), inDeg2.get(b)) || d3.ascending(a, b));

  const nRows = Math.max(col1.length, col2.length);
  const height = Math.max(minHeight, nRows * rowHeight + padY);

  const x0 = margin, x1 = width / 2, x2 = width - margin;
  const y0 = evenY(1, height);
  const y1 = evenY(col1.length, height);
  const y2 = evenY(col2.length, height);

  const pos0 = new Map(col0.map((d, i) => [d, y0[i]]));
  const pos1 = new Map(col1.map((d, i) => [d, y1[i]]));
  const pos2 = new Map(col2.map((d, i) => [d, y2[i]]));

  // fixed domain (not renormalized per component) -- a plain 1-to-1 target
  // in a component with no aggregation must not render as dark as a
  // genuinely aggregated target elsewhere just because it's the local max.
  const shade = d3.scaleSequential(d3.interpolateBlues).domain([0, maxIsic3Indegree]);

  const svg = d3.create("svg")
    .attr("viewBox", [0, 0, width, height])
    .attr("width", width)
    .attr("height", height)
    .attr("style", `max-width: 100%; height: auto; font: ${fontSize}px sans-serif;`);

  // stage 1 edges: isiccomb -> isic (dashed, one-to-many split, weight labelled)
  svg.append("g")
    .selectAll("path")
    .data(edgesForCode)
    .join("path")
      .attr("d", d => {
        const sy = pos0.get(d.isiccomb), ty = pos1.get(d.isic);
        return `M${x0},${sy} C${(x0 + x1) / 2},${sy} ${(x0 + x1) / 2},${ty} ${x1},${ty}`;
      })
      .attr("fill", "none")
      .attr("stroke", "#888")
      .attr("stroke-width", 1)
      .attr("stroke-dasharray", "3,2")
    .append("title")
      .text(d => `${d.isiccomb} -> ${d.isic}\nweight: ${d.weight.toFixed(3)}`);

  // stage 1 weight labels
  svg.append("g")
    .selectAll("text")
    .data(edgesForCode)
    .join("text")
      .attr("x", (x0 + x1) / 2)
      .attr("y", d => (pos0.get(d.isiccomb) + pos1.get(d.isic)) / 2 - 2)
      .attr("text-anchor", "middle")
      .attr("fill", "#666")
      .text(d => d.weight.toFixed(2));

  // stage 2 edges: isic -> isic.3 (solid, one-to-one, no label -- repeats stage 1 weight)
  const stage2 = Array.from(new Map(edgesForCode.map(d => [d.isic, d])).values());
  svg.append("g")
    .selectAll("path")
    .data(stage2)
    .join("path")
      .attr("d", d => {
        const sy = pos1.get(d.isic), ty = pos2.get(d.isic3);
        return `M${x1},${sy} C${(x1 + x2) / 2},${sy} ${(x1 + x2) / 2},${ty} ${x2},${ty}`;
      })
      .attr("fill", "none")
      .attr("stroke", "#888")
      .attr("stroke-width", 1)
    .append("title")
      .text(d => `${d.isic} -> ${d.isic3}\nweight: ${d.weight.toFixed(3)}`);

  // col0 node: italic (one-to-many source)
  svg.append("circle").attr("cx", x0).attr("cy", y0[0]).attr("r", 3).attr("fill", "#333");
  svg.append("text")
    .attr("x", x0 - 6).attr("y", y0[0]).attr("dy", "0.32em")
    .attr("text-anchor", "end").attr("font-style", "italic").attr("font-weight", 600)
    .text(isiccomb);

  // col1 nodes: bold (one-to-one sources for stage 2)
  svg.append("g")
    .selectAll("circle")
    .data(col1)
    .join("circle")
      .attr("cx", x1).attr("cy", d => pos1.get(d)).attr("r", 2.5).attr("fill", "#333");
  svg.append("g")
    .selectAll("text")
    .data(col1)
    .join("text")
      .attr("x", x1).attr("y", d => pos1.get(d)).attr("dy", "-0.5em")
      .attr("text-anchor", "middle").attr("font-weight", 600)
      .text(d => d);

  // col2 nodes: shaded by in-degree ("how synthetic")
  svg.append("g")
    .selectAll("circle")
    .data(col2)
    .join("circle")
      .attr("cx", x2).attr("cy", d => pos2.get(d)).attr("r", 6)
      .attr("fill", d => shade(inDeg2.get(d)))
      .attr("stroke", "#333").attr("stroke-width", 0.5)
    .append("title")
      .text(d => `${d} -- ${inDeg2.get(d)} isic member(s) feed into this parent`);
  svg.append("g")
    .selectAll("text")
    .data(col2)
    .join("text")
      .attr("x", x2 + 10).attr("y", d => pos2.get(d)).attr("dy", "0.32em")
      .attr("text-anchor", "start")
      .text(d => d);

  return svg.node();
}

// 2-column diagram: isiccomb -> isic.3 directly (the isic intermediate is
// already composed away). Used by (d) -- the whole-classification
// overview. Target-node shading is by the composed weight itself (already
// a [0, 1] fraction), not by in-degree -- a different metric than the
// 3-column diagram's, since there's no isic layer left to count children of.
export function buildComposedNodeLink2Col(d3, edgesForCode, {
  width = 220,
  rowHeight = 20,
  padY = 24,
  minHeight = 60,
  margin = 54,
} = {}) {
  const isiccomb = edgesForCode[0].isiccomb;

  const col0 = [isiccomb];
  const col1 = d3.sort(edgesForCode, d => -d.weight).map(d => d.isic3);

  const height = Math.max(minHeight, col1.length * rowHeight + padY);

  const x0 = margin, x1 = width - margin;
  const y0 = evenY(1, height);
  const y1 = evenY(col1.length, height);

  const pos0 = new Map(col0.map((d, i) => [d, y0[i]]));
  const pos1 = new Map(col1.map((d, i) => [d, y1[i]]));

  // fixed [0, 1] domain -- weights here are already fractions of the source
  // isiccomb code's value, so "how dark" (how much of this code's value
  // lands here) means the same thing in every small multiple.
  const shade = d3.scaleSequential(d3.interpolateBlues).domain([0, 1]);

  const svg = d3.create("svg")
    .attr("viewBox", [0, 0, width, height])
    .attr("width", width)
    .attr("height", height)
    .attr("style", "max-width: 100%; height: auto; font: 10px sans-serif;");

  // isiccomb -> isic.3, dashed (splitting), weight labelled
  svg.append("g")
    .selectAll("path")
    .data(edgesForCode)
    .join("path")
      .attr("d", d => {
        const sy = pos0.get(d.isiccomb), ty = pos1.get(d.isic3);
        return `M${x0},${sy} C${(x0 + x1) / 2},${sy} ${(x0 + x1) / 2},${ty} ${x1},${ty}`;
      })
      .attr("fill", "none")
      .attr("stroke", "#888")
      .attr("stroke-width", 1)
      .attr("stroke-dasharray", "3,2")
    .append("title")
      .text(d => `${d.isiccomb} -> ${d.isic3}\nweight: ${d.weight.toFixed(3)}`);

  svg.append("g")
    .selectAll("text")
    .data(edgesForCode)
    .join("text")
      .attr("x", (x0 + x1) / 2)
      .attr("y", d => (pos0.get(d.isiccomb) + pos1.get(d.isic3)) / 2 - 2)
      .attr("text-anchor", "middle")
      .attr("fill", "#666")
      .text(d => d.weight.toFixed(2));

  svg.append("circle").attr("cx", x0).attr("cy", y0[0]).attr("r", 3).attr("fill", "#333");
  svg.append("text")
    .attr("x", x0 - 6).attr("y", y0[0]).attr("dy", "0.32em")
    .attr("text-anchor", "end").attr("font-style", "italic").attr("font-weight", 600)
    .text(isiccomb);

  svg.append("g")
    .selectAll("circle")
    .data(col1)
    .join("circle")
      .attr("cx", x1).attr("cy", d => pos1.get(d)).attr("r", 6)
      .attr("fill", d => shade(edgesForCode.find(e => e.isic3 === d).weight))
      .attr("stroke", "#333").attr("stroke-width", 0.5)
    .append("title")
      .text(d => `${d} -- receives ${edgesForCode.find(e => e.isic3 === d).weight.toFixed(3)} of ${isiccomb}'s value`);
  svg.append("g")
    .selectAll("text")
    .data(col1)
    .join("text")
      .attr("x", x1 + 10).attr("y", d => pos1.get(d)).attr("dy", "0.32em")
      .attr("text-anchor", "start")
      .text(d => d);

  return svg.node();
}
