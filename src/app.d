import std.path : baseName, dirSeparator, setExtension, stripExtension;
import std.stdio;
import std.file;
import dxml.dom;
import std.conv : to;

import std.experimental.logger;

void main() {
	// Create the outpur dir if not exists
	if (!exists("output")) {
		mkdir("output");
	}

	foreach (file; dirEntries("xml", "*.xml", SpanMode.shallow)) {
		info("Parsing file ", file);

		File fl = initializeFile(file);
		auto dom = parseDOM!simpleXML(readText(file));

		foreach (c; dom.children[0].children) {
			switch (c.name) {
			case "struct":
				parseXcbStruct(c, fl);
				break;

			case "enum":
				parseXcbEnum(c, fl);
				break;

			case "import":
				parseXcbImport(c, fl);
				break;

			default:
				break;
			}
		}
	}
}

private:
File initializeFile(string path) @trusted {
	string fileName = path.baseName;
	File fl = File("output" ~ dirSeparator ~ fileName.setExtension("d"), "w");
	fl.write("module xcb." ~ fileName.stripExtension ~ ";\n\npublic extern(C) nothrow @nogc:\n\n");

	return fl;
}

string toDlangType(string xcbType) {
	switch (xcbType) {
	case "INT8":
		return "byte";

	default:
		return xcbType;
	}
}

void parseXcbStruct(ref DOMEntity!(string) entity, ref File outFile) {
	import std.array : insertInPlace;

	string[] result;
	result ~= "struct " ~ entity.attributes[0].value ~ " {\n";

	int aligns = 0;
	foreach (c; entity.children) {
		auto attrs = c.attributes;
		if (c.name == "pad") {
			if (attrs[0].name == "align") {
				result.insertInPlace(1, "align(" ~ attrs[0].value ~ "):");
			} else if (attrs[0].name == "bytes") {
				result ~= "\tbyte[" ~ attrs[0].value ~ "] align" ~ (aligns++).to!string() ~ ";";
			} else {
				warning("Cannot parse pad '", attrs[0].name, "'");
			}
		} else if (c.name == "field") {
			string name = attrs[0].value;
			string type = attrs[1].value;

			result ~= "\t" ~ name ~ " " ~ type ~ ";";
		} else {
			warning("Struct parser cannot handle ", c.name);
		}
	}

	foreach (r; result) {
		outFile.writeln(r);
	}
	outFile.writeln("}\n");
}

void parseXcbEnum(ref DOMEntity!(string) entity, ref File outFile) {
	string enumName = entity.attributes[0].value;
	outFile.writeln("enum " ~ enumName ~ " {");
	
	string[] values;
	foreach (c; entity.children) {
		auto attrs = c.attributes;
		if (attrs.length) {
			string name = attrs[0].value;
			immutable bool isBit = c.children[0].name == "bit";
			string val = c.children[0].children[0].text;

			values ~= name;

			if (isBit) {
				outFile.writeln("\t" ~ name ~ " = 1 << " ~ val ~ ",");
			} else {
				outFile.writeln("\t" ~ name ~ " = " ~ val ~ ",");
			}
		}
	}
	outFile.writeln("}\n");

	foreach (v; values) {
		outFile.write("alias " ~ v ~ " = " ~ enumName ~ "." ~ v ~ ";\n");
	}
	outFile.writeln();
}

void parseXcbImport(ref DOMEntity!(string) entity, ref File outFile) {
	outFile.writeln("import xcb." ~ entity.children[0].text ~ ";");
}
