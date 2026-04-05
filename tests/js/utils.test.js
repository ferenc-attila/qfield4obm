const fs = require("fs");
const path = require("path");

// Load Utils.js, stripping the QML-specific ".pragma library" directive
const utilsSrc = fs
    .readFileSync(path.join(__dirname, "../../scripts/Utils.js"), "utf-8")
    .replace(/^\.pragma library\s*/m, "");

// Evaluate in a function scope so the top-level `function` declarations
// become local, then return them as an object.
const Utils = new Function(
    utilsSrc +
    "\nreturn { hexToQgisColor, buildQgisStyleXml, writeStyleFile, geojsonGeomToWkt };"
)();

describe("hexToQgisColor", () => {
    it("converts #rrggbb to r,g,b,255 by default", () => {
        expect(Utils.hexToQgisColor("#e6194b")).toBe("230,25,75,255");
    });

    it("uses custom alpha when provided", () => {
        expect(Utils.hexToQgisColor("#ff0000", 128)).toBe("255,0,0,128");
    });

    it("returns fallback for invalid input", () => {
        expect(Utils.hexToQgisColor(null)).toBe("230,25,75,255");
        expect(Utils.hexToQgisColor("#abc")).toBe("230,25,75,255");
    });
});

describe("buildQgisStyleXml", () => {
    it("generates marker XML for Point geometry", () => {
        const xml = Utils.buildQgisStyleXml(
            { color: "#3cb44b", sizeOrThickness: 5, styleType: "Square" },
            "Point"
        );
        expect(xml).toContain('type="marker"');
        expect(xml).toContain('class="SimpleMarker"');
        expect(xml).toContain('value="square" name="name"');
        expect(xml).toContain('value="5" name="size"');
        expect(xml).toContain("60,180,75,255");
    });

    it("generates line XML for Line geometry", () => {
        const xml = Utils.buildQgisStyleXml(
            { color: "#4363d8", sizeOrThickness: 2, styleType: "Dashed" },
            "Line"
        );
        expect(xml).toContain('type="line"');
        expect(xml).toContain('class="SimpleLine"');
        expect(xml).toContain('value="dash" name="line_style"');
        expect(xml).toContain('value="2" name="line_width"');
    });

    it("generates fill XML for Polygon geometry", () => {
        const xml = Utils.buildQgisStyleXml(
            { color: "#e6194b", sizeOrThickness: 3, styleType: "Solid Fill" },
            "Polygon"
        );
        expect(xml).toContain('type="fill"');
        expect(xml).toContain('class="SimpleFill"');
        expect(xml).toContain('value="solid" name="style"');
    });

    it("uses alpha 0 for No Fill style", () => {
        const xml = Utils.buildQgisStyleXml(
            { color: "#e6194b", styleType: "No Fill" },
            "Polygon"
        );
        expect(xml).toContain('value="no" name="style"');
        expect(xml).toContain("230,25,75,0");
    });

    it("uses default values for missing config fields", () => {
        const xml = Utils.buildQgisStyleXml({}, "Point");
        expect(xml).toContain('type="marker"');
        expect(xml).toContain('value="circle" name="name"');
        expect(xml).toContain('value="3" name="size"');
    });

    it("generates valid XML structure", () => {
        const xml = Utils.buildQgisStyleXml(
            { color: "#ff0000", sizeOrThickness: 4, styleType: "Circle" },
            "Point"
        );
        expect(xml).toContain("<!DOCTYPE qgis");
        expect(xml).toContain('<qgis version="3.28"');
        expect(xml).toContain('<renderer-v2 type="singleSymbol"');
        expect(xml).toContain("</qgis>");
    });
});

describe("writeStyleFile", () => {
    it("writes .qml file and returns true on success", () => {
        let writtenPath = null;
        let writtenContent = null;
        const mockFileUtils = {
            writeFileContent: (path, content) => {
                writtenPath = path;
                writtenContent = content;
                return true;
            },
        };

        const result = Utils.writeStyleFile(
            "/data/layer.gpkg",
            { color: "#e6194b", sizeOrThickness: 3, styleType: "Circle" },
            "Point",
            mockFileUtils,
            null
        );

        expect(result).toBe(true);
        expect(writtenPath).toBe("/data/layer.qml");
        expect(writtenContent).toContain('class="SimpleMarker"');
    });

    it("returns false when dataFilePath is missing", () => {
        const result = Utils.writeStyleFile(null, { color: "#e6194b" }, "Point", {}, null);
        expect(result).toBe(false);
    });

    it("returns false when FileUtils.writeFileContent throws", () => {
        const mockFileUtils = {
            writeFileContent: () => { throw new Error("disk full"); },
        };

        const result = Utils.writeStyleFile(
            "/data/layer.gpkg",
            { color: "#e6194b" },
            "Point",
            mockFileUtils,
            null
        );

        expect(result).toBe(false);
    });
});