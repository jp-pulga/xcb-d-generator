module token;

import std.stdio : File;
import std.uni : isNumber, isUpper, isLower, toLower, toUpper;

private struct TKStruct;
private struct TKEnum;
private struct TKAlign;
private struct TKStMember;
private struct TKEnMember;
private struct TKAlias;

/// Token struct
public struct Token(T) {
public:
	static if (is(T == TKStruct) || is(T == TKEnum) || is(T == TKStMember)) {
		string snakeName() inout @property @trusted {
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
					if (input[index].isUpper && (input[index - 1].isLower ||
							input[index - 1].isNumber))
						output ~= "_";
				}

				return output ~ input[$ - 1 .. $];
			}

			if (_name.length < 2)
				return _name.toLower;

			string output = firstPass(_name);
			output = secondPass(output);

			return output.toLower;
		}
	}

	static if (is(T == TKStruct) || is(T == TKEnum)) {
		string xcbName() inout @property @trusted {
			if (_prefix.length) {
				return "xcb_" ~ _prefix ~ "_" ~ snakeName() ~ _sufix;
			} else {
				return "xcb_" ~ snakeName() ~ _sufix;
			}
		}
	}

	//	string dType() inout @property @trusted {
	//		switch (_prefix) {
	//		case "BOOL":
	//		case "BYTE":
	//		case "CARD8":
	//		case "INT8":
	//			return "byte";
	//
	//		case "CARD16":
	//		case "INT16":
	//			return "short";
	//
	//		case "CARD32":
	//		case "INT32":
	//			return "int";
	//
	//		default:
	//			return "xcb_" ~ _prefix.toLower ~ "_t";
	//		}
	//	}

	static if (is(T == TKStruct)) {
		/// Add an member to the list of memebers
		void addMember(Token!TKStMember memeber) @trusted {
			_members ~= memeber;
		}

		/// Set the content alingment
		void setAlign(Token!TKAlign _align) @trusted {
			this._align = _align;
		}
	}

	static if (is(T == TKEnum)) {
		/// Add an member to the list of memebers
		void addMember(Token!TKEnMember memeber) @trusted {
			_members ~= memeber;
		}
	}

	static if (is(T == TKStruct) || is(T == TKEnum)) {
		/// Add an alias to the list of alisses
		void addAlias(Token!TKAlias _alias) @trusted {
			_aliases ~= _alias;
		}
	}

	static if (is(T == TKStMember) || is(T == TKEnMember)) {
		void setDoc(string doc) @trusted {
			_doc = doc;
		}
	}

	/// Write the token contents to some file
	void write(File fl) @trusted {
		static if (is(T == TKStruct)) {
			fl.writeln(_doc);
			fl.writeln("struct ", xcbName, " {");
			_align.write(fl);

			foreach (m; _members) {
				m.write(fl);
			}
			fl.writeln("}\n");

			foreach (a; _aliases) {
				a.write(fl);
			}
		} else static if (is(T == TKEnum)) {
			fl.writeln(_doc);
			fl.writeln("enum ", xcbName, " {");
			foreach (m; _members) {
				m.write(fl);
			}
			fl.writeln("}\n");

			foreach (a; _aliases) {
				a.write(fl);
			}
		} else static if (is(T == TKAlign)) {
			if (_value.length > 0)
				fl.writeln("align(", _value, "):");
		} else static if (is(T == TKStMember)) {
			fl.writeln("\t",_doc);
			fl.writeln("\t", _type, " ", _name, ";");
		} else static if (is(T == TKEnMember)) {
			fl.writeln("\t", _doc);
			fl.writeln("\t", _name, " = ", _value, ",");
		} else static if (is(T == TKAlias)) {
			string upperMember = _member.toUpper;
			fl.writeln(_doc);
			fl.writeln("alias ", upperMember, " = ", _type, ".", upperMember, ";");
		}
	}

private:
	static if (is(T == TKStruct)) {
		string _prefix;
		string _name;
		string _sufix;
		string _doc = "///";

		Token!TKAlign _align;
		Token!TKStMember[] _members;
		Token!TKAlias[] _aliases;
	} else static if (is(T == TKEnum)) {
		string _prefix;
		string _name;
		string _sufix;
		string _doc = "///";

		Token!TKEnMember[] _members;
		Token!TKAlias[] _aliases;
	} else static if (is(T == TKAlign)) {
		string _value;
	} else static if (is(T == TKStMember)) {
		string _type;
		string _name;
		string _doc = "///";
	} else static if (is(T == TKEnMember)) {
		string _name;
		string _value;
		string _doc = "///";
	} else static if (is(T == TKAlias)) {
		string _type;
		string _member;
		string _doc = "///";
	}
}

public alias new_struct = Token!TKStruct;
public alias new_enum = Token!TKEnum;
public alias new_struct_member = Token!TKStMember;
public alias new_enum_member = Token!TKEnMember;
public alias new_alias = Token!TKAlias;
public alias new_aling = Token!TKAlign;

///
public Token!TKStMember new_pad(string length, int pad) @trusted {
	import std.conv : to;

	if (length == "1") {
		return new_struct_member("ubyte", "pad" ~ pad.to!string ~ ";");
	}
	return new_struct_member("ubyte[" ~ length ~ "]", "pad" ~ pad.to!string ~ ";");
}
