import fs from "node:fs";

const bytes = fs.readFileSync(process.argv[2]);
const module = new WebAssembly.Module(bytes);
const instance = new WebAssembly.Instance(module, {
	env: {
		roc_dealloc() {},
		roc_crashed() {
			throw new Error("Roc crashed");
		},
	},
});
const result = instance.exports.wasm_main();

console.log(`result=${result}`);
process.exitCode = result;
