import dxml.dom;
import dxml.parser : TextPos;
import std.conv : to;
import std.experimental.logger;
import std.file;
import std.path : baseName, dirSeparator, setExtension, stripExtension;
import std.stdio;
import std.typecons;
import std.uni : isNumber, isUpper, isLower, toLower, toUpper;
import token;

alias Attribute = Tuple!(string, "name", string, "value", TextPos, "pos");
private immutable enum padFormat = "\tbyte[%s] pad%d;";

private enum Config {
	Reply,
	Request,
	Enum,
	Struct
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
				genericTypeWriter!(Config.Struct)(c, prefix, "", fl);
				break;

			case "enum":
				genericTypeWriter!(Config.Enum)(c, prefix, "", fl);
				break;

			case "request":
				genericTypeWriter!(Config.Request)(c, prefix, "", fl);
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

void genericTypeWriter(Config cfg)(ref DOMEntity!string dom, string prefix,
		string memName, ref File fl) {
	import std.format : format;
	import std.variant : Variant;

	static if (cfg == Config.Enum) {
		auto parent = new_enum(prefix, dom.attributes.byName("name").value, "_t");
		const string aliasBase = parent.xcbName[0 .. $ - 2];
	} else static if (cfg == Config.Struct) {
		auto parent = new_struct(prefix, dom.attributes[0].value, "_t");
	} else static if (cfg == Config.Request) {
		// First write the OP code
		string structName = dom.attributes[0].value;
		DOMEntity!string reply;
		int writed = 0;

		auto parent = new_struct(prefix, structName, "_request_t");
		parent.addDefine(new_define(structName, dom.attributes[1].value));
		parent.addMember(new_struct_member("ushort", "major_opcode"));
	} else static if (cfg == Config.Reply) {
		int writed = 0;

		auto parent = new_struct(prefix, memName, "_reply_t");
		parent.addMember(new_struct_member("ubyte", "response_type"));
	}

	int pad = 0;
	foreach (c; dom.children) {
		auto attrs = c.attributes;

		static if (cfg == Config.Request) {
			if (writed++ == 1) {
				parent.addMember(new_struct_member("ushort", "length"));
			}

		} else static if (cfg == Config.Reply) {
			if (writed++ == 1) {
				parent.addMember(new_struct_member("ushort", "sequence"));
				parent.addMember(new_struct_member("uint", "length"));
			}
		}
		switch (c.name()) {

			static if (cfg == Config.Struct) {
		case "pad":
				if (attrs[0].name == "align") {
					parent.setAlign(new_aling(attrs[0].value));
				} else if (attrs[0].name == "bytes") {
					parent.addMember(new_pad(attrs[0].value, pad++));
				} else {
					warning("Cannot parse pad '", attrs[0].name, "'");
				}
				break;
			} else static if (cfg == Config.Request || cfg == Config.Reply) {
		case "pad":
				parent.addMember(new_pad(attrs[0].value, pad++));
				break;
			}

			static if (cfg == Config.Enum) {
		case "item":
				if (attrs.length) {
					string memberName = (aliasBase ~ attrs[0].value).toUpper;
					immutable bool isBit = c.children[0].name == "bit";
					string val = c.children[0].children[0].text;

					parent.addAlias(new_alias(aliasBase, memberName));
					if (isBit) {
						parent.addMember(new_enum_member(memberName, "1 << " ~ val));
					} else {
						parent.addMember(new_enum_member(memberName, val));
					}
				}
				break;
			} else {
		case "field":
				string type = attrs.byName("type").value;
				string name = attrs.byName("name").value;

				parent.addMember(new_struct_member(type, name));
				break;
			}

			static if (cfg == cfg.Request) {
		case "reply":
				reply = c;
				break;
			}

		default:
			warning("Generic type wirter cannor hanle '", c.name, "'");
			break;
		}
	}

	parent.write(fl);

	static if (cfg == cfg.Request) {
		if (reply != DOMEntity!(string).init) {
			genericTypeWriter!(Config.Reply)(reply, prefix, structName, fl);
		}
	}
}

string parseXcbDeclaration(ref DOMEntity!string dom, ref File outFile) {
	if (dom.attributes.length >= 5) {

		enum format = "immutable enum XCB_%s_%s_VERSION = %s;";
		auto attrs = dom.attributes;
		outFile.writefln(format, attrs[2].value.toUpper, "MAJOR", attrs[3].value);
		outFile.writefln(format, attrs[2].value.toUpper, "MINOR", attrs[3].value);
		outFile.writeln();
		outFile.writefln("__gshared extern xcb_extension_t xcb_" ~ attrs[2].value.toLower ~ "_id;");
		outFile.writeln();

		return new_struct_member("", attrs[2].value).snakeName.toLower;
	}
	return "";
}

void parseXcbImport(ref DOMEntity!(string) dom, ref File outFile) {
	outFile.writeln("import xcb." ~ dom.children[0].text ~ ";");
}
