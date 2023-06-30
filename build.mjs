import coffeeScriptPlugin from 'esbuild-coffeescript';
import * as esbuild from 'esbuild';


let ctx = await esbuild.context({
  entryPoints: ['index.coffee'],
  bundle: true,
  outfile: 'index.js',
  sourcemap: true,
  plugins: [coffeeScriptPlugin({inlineMap: true})],
})

let wtf = await ctx.serve({
	servedir: '.'
})
console.log(wtf)
