"use strict";

const safeBraceExpansion = require("brace-expansion-safe");
const expand = safeBraceExpansion.expand;

module.exports = expand;
module.exports.expand = expand;
module.exports.EXPANSION_MAX = safeBraceExpansion.EXPANSION_MAX;
module.exports.EXPANSION_MAX_LENGTH = safeBraceExpansion.EXPANSION_MAX_LENGTH;
