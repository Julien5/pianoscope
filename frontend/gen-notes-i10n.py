#!/usr/bin/env python3

def quote(s):
	return "\""+s+"\"";

class Notes:
	def __init__(self,locale):
		self.table={};
		for k in ["C","D","E","F","G","A","B"]:
			self.table[k]=k;
		if locale == "DE":
			self.table["B"]="H";
		if locale == "FR":
			self.table["C"]="DO";
			self.table["D"]="RÉ";
			self.table["E"]="MI";
			self.table["F"]="FA";
			self.table["G"]="SOL";
			self.table["A"]="LA";
			self.table["B"]="SI";
	def gen(self):
		lines=[];
		for k in ["C","D","E","F","G","A","B"]:
			# "noteC": "C"
			left=quote(f"note{k:s}");
			right=quote(f"{self.table[k]:s}");
			lines.append(f"{left:s}:{right:s}");
		return ",\n  ".join(lines);

def main():
	for locale in ["EN","DE","FR"]:
		print("locale",locale);
		print(Notes(locale).gen());
		print();

if __name__ == "__main__":
	main();

