import type { Options } from 'tsup';

const env = process.env.NODE_ENV;

export const tsup: Options = {
    bundle: true,
    noExternal: [/./],
    skipNodeModulesBundle: false,
};