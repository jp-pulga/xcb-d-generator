module parsers.parser;

import std.path : baseName, dirSeparator, setExtension, stripExtension;
import std.stdio;
import std.file;
import dxml.parser;
import std.conv : to;

import std.experimental.logger;

public:
void parseXmlFiles() @trusted {
	// Create the outpur dir if not exists
	if (!exists("output")) {
		mkdir("output");
	}

	foreach (file; dirEntries("xml", "*.xml", SpanMode.shallow)) {
		info("Parsing file ", file);

		File fl = initializeFile(file);
		auto contents = parseXML!simpleXML(readText(file));

		while (!contents.empty) {
			switch (contents.front.name) {
				case "struct":
					parseXcbStruct(contents, fl);
					break;

				case "enum":
					parseXcbEnum(contents, fl);
					break;

				case "import":
					parseXcbImport(contents, fl);
					break;

				default:
					break;
			}

			contents.popToElementStart();
		}
	}
}

private:
File initializeFile(string path) @trusted {
	string fileName = path.baseName;
	File fl = File("output" ~ dirSeparator ~ fileName.setExtension("d"), "w");
	fl.write("module xcb." ~ fileName.stripExtension ~";\n\npublic extern(C) nothrow @nogc:\n\n");

	return fl;
}

void popToElementStart(ref EntityRange!(simpleXML, string) entity) {
	entity.popFront();

	while(!entity.empty && entity.front.type != EntityType.elementStart) {
		entity.popFront();
	}
}

void parseXcbStruct(ref EntityRange!(simpleXML, string) entity, ref File outFile) {
	outFile.writeln("struct " ~ entity.front.attributes.front.value ~ " {");

	entity.popToElementStart();

	while (entity.front.name == "field") {
		auto attrs = entity.front.attributes;
		if (!attrs.empty) {
			string name = attrs.front.value;
			attrs.popFront();
			string type = attrs.front.value;

			outFile.writeln("\t" ~ name ~ " " ~ type ~ ";");
		}

		entity.popToElementStart();
	}
	outFile.writeln("}\n");
}

void parseXcbEnum(ref EntityRange!(simpleXML, string) entity, ref File outFile) {
	string enumName = entity.front.attributes.front.value;
	outFile.writeln("enum " ~ enumName ~ " {");

	entity.popToElementStart();

	string[] values;
	while (entity.front.name == "item") {
		auto attrs = entity.front.attributes;
		if (!attrs.empty) {
			string name = attrs.front.value;
			entity.popToElementStart();
			bool isBit = entity.front.name == "bit";
			entity.popFront();
			string val = entity.front.text;

			values ~= name;

			if (isBit) {
				outFile.writeln("\t" ~ name ~ " = 1 << " ~ val ~ ";");
			} else {
				outFile.writeln("\t" ~ name ~ " = " ~ val ~ ";");
			}
		}

		entity.popToElementStart();
	}
	outFile.writeln("}\n");

	foreach (v; values) {
		outFile.write("alias " ~ v ~ " = " ~ enumName ~ "." ~ v ~ ";\n");
	}
	outFile.writeln();
}

void parseXcbImport(ref EntityRange!(simpleXML, string) entity, ref File outFile) {
	entity.popFront();

	outFile.writeln("import xcb." ~ entity.front.text ~ ";");
}