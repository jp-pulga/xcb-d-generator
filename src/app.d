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

		immutable string prefix = parseXcbDeclaration(dom.children[0], fl);
		foreach (c; dom.children[0].children) {
			switch (c.name) {
			case "struct":
				parseXcbStruct(c, prefix, fl);
				break;

			case "enum":
				parseXcbEnum(c, prefix, fl);
				break;

			case "import":
				parseXcbImport(c, fl);
				break;

			case "request":
				parseXcbRequest(c, fl);
				break;

			default:
				warning("Cannot parse member '", c.name, "'");
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

string toSnakeCase(string name) {
	import std.range : Appender;
	import std.uni : isUpper, toLower;

	Appender!string res;

	foreach(s; name) {
		if (s.isUpper) {
			res.put("_");
			res.put(s.toLower);
		} else {
			res.put(s);
		}
	}

	return res.data;
}

string toXcbName(string name, string prefix, string sufix) {
	return "xcb_" ~ prefix ~ name.toSnakeCase() ~ sufix;
}

string toDlangType(string xcbType) {
	switch (xcbType) {
	case "INT8":
		return "byte";

	default:
		return xcbType;
	}
}

string parseXcbDeclaration(ref DOMEntity!string dom, ref File outFile) {
	if (dom.attributes.length == 5) {
		import std.uni : toUpper, toLower;

		enum format = "immutable enum XCB_%s_%s_VERSION = %s;";
		auto attrs = dom.attributes;
		outFile.writefln(format, attrs[2].value.toUpper, "MAJOR", attrs[3].value);
		outFile.writefln(format, attrs[2].value.toUpper, "MINOR", attrs[3].value);
		outFile.writeln();

		return attrs[2].value.toLower;
	}
	return "";
}

void parseXcbStruct(ref DOMEntity!string dom, string prefix, ref File outFile) {
	import std.array : insertInPlace;

	string[] result;
	result ~= "struct " ~ dom.attributes[0].value.toXcbName(prefix, "_t") ~ " {\n";

	int aligns = 0;
	foreach (c; dom.children) {
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

void parseXcbEnum(ref DOMEntity!string dom, string prefix, ref File outFile) {
	string enumName = dom.attributes[0].value;
	outFile.writeln("enum " ~ enumName.toXcbName(prefix, "_t") ~ " {");

	string[] values;
	foreach (c; dom.children) {
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

void parseXcbImport(ref DOMEntity!(string) dom, ref File outFile) {
	outFile.writeln("import xcb." ~ dom.children[0].text ~ ";");
}

void parseXcbRequest(ref DOMEntity!string dom, ref File outFile) {

}
