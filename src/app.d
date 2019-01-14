import std.path : baseName, dirSeparator, setExtension, stripExtension;
import std.stdio;
import std.file;
import dxml.dom;
import dxml.parser : TextPos;
import std.conv : to;
import std.typecons;

import std.experimental.logger;

alias Attribute = Tuple!(string, "name", string, "value", TextPos, "pos");
private immutable enum padFormat = "\tbyte[%s] pad%d;";

private struct Config {
	bool reply;
	bool enum_;
	bool struct_;
}

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
				genericTypeWriter!(Config(false, false, true))(c, prefix, "", fl);
				break;

			case "enum":
				genericTypeWriter!(Config(false, true, false))(c, prefix, "", fl);
				break;

			case "request":
				genericTypeWriter!(Config(true, false, false))(c, prefix, "", fl);
				break;

			case "import":
				parseXcbImport(c, fl);
				break;

			default:
				warning("Cannot parse member '", c.name, "'");
				break;
			}
		}
	}
}

private:

Attribute byName(Attribute[] attrs, string name) {
	foreach (attr; attrs) {
		if (attr.name == name) {
			return attr;
		}
	}

	return Attribute.init;
}

File initializeFile(string path) @trusted {
	string fileName = path.baseName;
	File fl = File("output" ~ dirSeparator ~ fileName.setExtension("d"), "w");
	fl.write("module xcb." ~ fileName.stripExtension ~ ";\n\npublic extern(C) nothrow @nogc:\n\n");

	return fl;
}

string toSnakeCase(const string input) {
	import std.uni : isNumber, isUpper, isLower, toLower;

	string firstPass(const string input) {
		if (input.length < 3)
			return input;

		string output;
		for (auto index = 2; index < input.length; index++) {
			output ~= input[index - 2];
			if (input[index - 1].isUpper && input[index].isLower)
				output ~= "_";
		}

		return output ~ input[$ - 2 .. $];
	}

	string secondPass(const string input) {
		if (input.length < 2)
			return input;

		string output;
		for (auto index = 1; index < input.length; index++) {
			output ~= input[index - 1];
			if (input[index].isUpper && (input[index - 1].isLower || input[index - 1].isNumber))
				output ~= "_";
		}

		return output ~ input[$ - 1 .. $];
	}

	if (input.length < 2)
		return input.toLower;

	string output = firstPass(input);
	output = secondPass(output);

	return output.toLower;
}

string toXcbName(string name, string prefix, string sufix) {
	if (prefix.length) {
		return "xcb_" ~ prefix ~ "_" ~ name.toSnakeCase() ~ sufix;
	} else {
		return "xcb_" ~ name.toSnakeCase() ~ sufix;
	}
}

string toDlangType(string xcbType) {
	import std.uni : toLower;

	switch (xcbType) {
	case "BYTE":
	case "CARD8":
	case "INT8":
		return "byte";

	case "CARD16":
	case "INT16":
		return "short";

	case "CARD32":
	case "INT32":
		return "int";

	default:
		return "xcb_" ~ xcbType.toLower ~ "_t";
	}
}

void genericTypeWriter(Config cfg)(ref DOMEntity!string dom, string prefix,
		string memName, ref File outFile) {
	import std.format : format;
	import std.uni : toUpper;

	static if (cfg.enum_) {
		string xcbMemName = dom.attributes.byName("name").value.toXcbName(prefix, "_t");
		immutable string shortName = xcbMemName[0 .. $ - 1].toUpper;
		string[] enumMembers;

		outFile.writeln("enum " ~ xcbMemName ~ " {");
	} else static if (cfg.struct_) {
		import std.array : insertInPlace;

		string[] result;
		result ~= format("struct " ~ dom.attributes[0].value.toXcbName(prefix, "_t") ~ " {");
	} else static if (cfg.reply) {
		// First write the OP code
		string structName = dom.attributes[0].value;
		DOMEntity!string reply;

		outFile.writeln("immutable enum " ~ structName.toXcbName("",
				"") ~ " = " ~ dom.attributes[1].value ~ ";");
		outFile.writeln("struct " ~ dom.attributes[0].value.toXcbName(prefix, "_request_t") ~ " {");
	} else {
		outFile.writeln("struct " ~ memName.toXcbName(prefix, "_reply_t") ~ " {");
		outFile.writeln("\tubyte response_type;");
		int writed = 0;
	}

	int pad = 0;
	foreach (c; dom.children) {
		auto attrs = c.attributes;

		static if (!cfg.reply && !cfg.enum_ && !cfg.struct_) {
			if (writed++ == 1) {
				outFile.writeln("\tushort sequence;");
				outFile.writeln("\tuint length;");
			}
		}
		switch (c.name()) {

			static if (cfg.struct_) {
		case "pad":
				if (attrs[0].name == "align") {
					result.insertInPlace(1, "align(" ~ attrs[0].value ~ "):");
				} else if (attrs[0].name == "bytes") {
					result ~= format(padFormat, attrs[0].value, pad++);
				} else {
					warning("Cannot parse pad '", attrs[0].name, "'");
				}
				break;
			} else {
		case "pad":
				outFile.writefln(padFormat, c.attributes[0].value, pad++);
				break;
			}

			static if (cfg.enum_) {
		case "item":
				if (attrs.length) {
					string name = shortName ~ attrs[0].value.toSnakeCase.toUpper;
					immutable bool isBit = c.children[0].name == "bit";
					string val = c.children[0].children[0].text;

					enumMembers ~= name;

					if (isBit) {
						outFile.writeln("\t" ~ name ~ " = 1 << " ~ val ~ ",");
					} else {
						outFile.writeln("\t" ~ name ~ " = " ~ val ~ ",");
					}
				}
				break;
			} else static if (cfg.struct_) {
		case "field":
				string type = attrs.byName("type").value.toDlangType;
				string name = attrs.byName("name").value;

				result ~= "\t" ~ type ~ " " ~ name ~ ";";
				break;
			} else {
		case "field":
				string type = attrs.byName("type").value.toDlangType;
				string name = attrs.byName("name").value;

				outFile.writeln("\t" ~ type ~ " " ~ name ~ ";");
				break;
			}

			static if (cfg.reply) {
		case "reply":
				reply = c;
				break;
			}

		default:
			warning("Generic type wirter cannor hanle '", c.name, "'");
			break;
		}
	}

	static if (cfg.struct_) {
		foreach (r; result) {
			outFile.writeln(r);
		}
	}

	outFile.writeln("}\n");

	static if (cfg.enum_) {
		foreach (m; enumMembers) {
			outFile.write("alias " ~ m ~ " = " ~ shortName ~ "." ~ m ~ ";\n");
		}
		outFile.writeln();
	}

	static if (cfg.reply) {
		if (reply != DOMEntity!(string).init) {
			genericTypeWriter!(Config(false, false, false))(reply, prefix, structName, outFile);
		}
	}
}

string parseXcbDeclaration(ref DOMEntity!string dom, ref File outFile) {
	if (dom.attributes.length >= 5) {
		import std.uni : toUpper, toLower;

		enum format = "immutable enum XCB_%s_%s_VERSION = %s;";
		auto attrs = dom.attributes;
		outFile.writefln(format, attrs[2].value.toUpper, "MAJOR", attrs[3].value);
		outFile.writefln(format, attrs[2].value.toUpper, "MINOR", attrs[3].value);
		outFile.writeln();
		outFile.writefln("__gshared extern xcb_extension_t xcb_" ~ attrs[2].value.toLower ~ "_id;");
		outFile.writeln();

		return attrs[2].value.toSnakeCase.toLower;
	}
	return "";
}

void parseXcbImport(ref DOMEntity!(string) dom, ref File outFile) {
	outFile.writeln("import xcb." ~ dom.children[0].text ~ ";");
}
