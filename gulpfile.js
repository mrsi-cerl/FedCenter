/* gulpfile.js */

/**
 * Import uswds-compile
 */
const uswds = require("@uswds/compile");

/**
 * USWDS version
 * Set the major version of USWDS you're using
 * (Current options are the numbers 2 or 3)
 */
uswds.settings.version = 3;

/**
 * Paths
 * dist refers to where we compile the css to
 * see https://designsystem.digital.gov/documentation/getting-started/developers/phase-two-compile/#step-5-customize-path-settings-2
 */
uswds.paths.dist.img = "src/components/uswds/img";
uswds.paths.dist.css = "src/components/uswds/css";

/**
 * Exports
 * Add as many as you need
 */
exports.init = uswds.init;
exports.compile = uswds.compile;
exports.watch = uswds.watch;
