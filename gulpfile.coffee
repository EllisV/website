gulp = require 'gulp'
# Loads the plugins without having to list all of them, but you need
# to call them as $.pluginname
$ = require('gulp-load-plugins')()
# "del" is used to clean out directories and such
del = require 'del'
# BrowserSync isn't a gulp package, and needs to be loaded manually
browserSync = require('browser-sync').create()
# Need a command for reloading webpages using BrowserSync
reload = browserSync.reload
# FS library is used for creating .nojekyll file
fs = require 'fs'

gulp.task 'clean', del.bind(null, ['dist'])

gulp.task 'jekyll:dev', $.shell.task('bundle exec jekyll build')
gulp.task 'jekyll-rebuild', ['jekyll:dev'], reload

gulp.task 'jekyll:prod', ['clean'], $.shell.task('bundle exec jekyll build --config _config.yml,_config.build.yml')

gulp.task 'styles', ->
  gulp.src 'src/_assets/styles/app.scss'
    .pipe $.sass(includePaths: ['src/_assets/bower_components'])
    .pipe $.autoprefixer(['> 1%', 'last 2 versions', 'Firefox ESR', 'Opera 12.1'], cascade: true)
    .pipe $.minifyCss(compatibility: 'ie8')
    .pipe gulp.dest('dist/css/')
    .pipe $.size(title: 'styles')

gulp.task 'scripts', ->
  files = ((options) ->
    reformatted = {}
    reformatter = (value) ->
      "src/_assets/scripts/#{value}"

    for prop of options
      reformatted[prop] = options[prop].map reformatter

    reformatted
  )(require('./src/_assets/scripts/concat.json'))

  for file, scripts of files
    gulp.src scripts
      .pipe $.if(/[.]coffee$/, $.coffee(bare: true).on('error', $.util.log))
      .pipe $.concat(file)
      .pipe $.uglify()
      .pipe gulp.dest('dist/js/')
      .pipe $.size(title: file)

gulp.task 'html', ['jekyll:prod'], ->
  gulp.src './dist/**/*.html'
    .pipe $.minifyHtml(conditionals: true)
    .pipe gulp.dest('dist')

gulp.task 'serve', ->
  browserSync.init server: './dist'

gulp.task 'doctor', $.shell.task('bundle exec jekyll doctor')

gulp.task 'jslint', ->
  gulp.src 'src/_assets/scripts/**/*.js'
    .pipe $.jshint('.jshintrc')
    .pipe $.jshint.reporter()

gulp.task 'coffeelint', ->
  gulp.src 'src/_assets/scripts/**/*.coffee'
    .pipe $.coffeelint()
    .pipe $.coffeelint.reporter()

# These tasks will look for files that change while serving and will auto-regenerate or
# reload the website accordingly. Update or add other files you need to be watched.
gulp.task 'watch', ->
  gulp.watch ['src/**/*.md', 'src/**/*.html', 'src/**/*.xml', 'src/**/*.txt'], ['jekyll-rebuild']
  gulp.watch ['dist/assets/css/*.css', 'dist/assets/scripts/*.js'], reload
  gulp.watch ['src/_assets/styles/**/*.{sass,scss}'], ['styles']
  gulp.watch ['src/_assets/scripts/**/*.{js,coffee}', 'src/_assets/scripts/concat.json'], ['scripts']

# Default task, run when just writing "gulp" in the terminal
gulp.task 'default', ['styles', 'scripts', 'jekyll:dev', 'serve', 'watch']

# Checks your JS and Jekyll for errors
gulp.task 'check', ['jslint', 'coffeelint', 'doctor']

# Builds the site but doesn't serve it to you
gulp.task 'build', ['jekyll:prod', 'html', 'scripts', 'styles']

# Task to upload your site to your personal GH Pages repo
gulp.task 'deploy', ->
  # TODO: fix a bug that .nojekyll is not added when .publish does not exist (the first time)
  try
    fs.mkdirSync '.publish'
  catch e
    throw e if e.code != 'EEXIST'

  fs.closeSync fs.openSync('.publish/.nojekyll', 'w')

  gulp.src './dist/**/*'
    .pipe $.ghPages(
      remoteUrl: 'git@github.com:EllisV/ellisv.github.io.git'
      branch: 'master'
      force: true
    )
