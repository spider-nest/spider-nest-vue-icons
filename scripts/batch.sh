#! /usr/bin/bash
## Batch build components from v2/*.svg

gen(){
# get base name in format of given component e.g. picture-outlined.svg
# will result in `picture-outlined`
BASE_NAME="$(basename -- ${1} | cut -d '.' -f 1 )"
# genrate filename removing symbol `_` and `-`
filename="$(echo $BASE_NAME | sed 's/[_|-]\([a-z]\)/\ \1/g;s/^\([a-z]\)/\ \1/g')"
# translate *.svg into vue.h function with h(path, { d: 'anyD'}, null)
# if multiple then add them into a list.
p="$(cat ${1} | grep -Eo 'd="[^"]+"' | sed -r 's/d="(.+)"/h("path", { d: "\1" }, null),\n/g')"
normalized=""
for name in $filename;
do
  # normalize filename with PascalCased name
  # e.g. picture outlined
  # transform into PictureOutlined
  c="$(echo "${name:0:1}" | tr "[:lower:]" "[:upper:]")"
  normalized="${normalized}${c}${name:1}"
done
# struturing the main file then piping to
# `packages/component/[filename].ts`
cat << EOF > "packages/components/${BASE_NAME}.ts"
import type { FunctionalComponent } from 'vue'

import { h } from 'vue'

import Icon from '../icon/icon'

const ${normalized} = function (props: any) {
  return h(
    Icon,
    props,
    {
      default: () => [${p}],
    },
  );
} as FunctionalComponent;

${normalized}.displayName = 'ElIcon${normalized}';

export default ${normalized};

EOF
# preparing install function injection
echo "${normalized}," >> ./temp
# Also add the reference into `packages/index.ts` for universal build
echo "import ${normalized} from './components/${BASE_NAME}'" >> packages/index.ts
echo "export { default as ${normalized} } from './components/${BASE_NAME}'" >> packages/index.ts
}

export -f gen
# empty index.ts
echo "" > packages/index.ts
# gen ./v2/add-location.svg in case you want to use it directly
# find all file with extension `svg`, then call the function above
find . -name *.svg | sort | xargs -I {} bash -c 'gen "$@"' _ {}

# We also need to add Icon component into `pacages/index.ts`
# after these components built.
echo "export { default as Icon } from './icon/icon'" >> packages/index.ts
echo "export { default as getExternalIcons, ExternalIcon } from './icon/external-icon'" >> packages/index.ts
echo "import type { App } from 'vue'" >> packages/index.ts

INSTALL="export const install = (app: App) => {\n\
  [\n`cat temp`\n].forEach(comp => app.component(comp.displayName, comp)) \
  }
"
echo "$INSTALL" >> packages/index.ts

rm temp
