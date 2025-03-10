# Used by Makefile and configure for building Ruby.
# See common.mk and Makefile.in for details.

class File
  sep = ("\\" if RUBY_PLATFORM =~ /mswin|bccwin|mingw/)
  if sep != ALT_SEPARATOR
    remove_const :ALT_SEPARATOR
    ALT_SEPARATOR = sep
  end
end

[[libpathenv, "."], [preloadenv, libruby_so]].each do |env, path|
  env or next
  e = ENV[env] or next
  e = e.split(File::PATH_SEPARATOR)
  path = File.realpath(path, builddir) rescue next
  e.delete(path) or next
  ENV[env] = (e.join(File::PATH_SEPARATOR) unless e.empty?)
end

static = !!(defined?($static) && $static)
$:.unshift(builddir)
posthook = proc do
  RbConfig.fire_update!("top_srcdir", $top_srcdir)
  RbConfig.fire_update!("topdir", $topdir)
  $hdrdir.sub!(/\A#{Regexp.quote($top_srcdir)}(?=\/)/, "$(top_srcdir)")
  if $extmk
    $ruby = "$(topdir)/miniruby -I'$(topdir)' -I'$(top_srcdir)/lib' -I'$(extout)/$(arch)' -I'$(extout)/common'"
  else
    $ruby = baseruby
  end
  $static = static
  untrace_var(:$ruby, posthook)
end
prehook = proc do |extmk|
=begin
  pat = %r[(?:\A(?:\w:|//[^/]+)|\G)/[^/]*]
  dir = builddir.scan(pat)
  pwd = Dir.pwd.scan(pat)
  if dir[0] == pwd[0]
    while dir[0] and dir[0] == pwd[0]
      dir.shift
      pwd.shift
    end
    builddir = File.join((pwd.empty? ? ["."] : [".."]*pwd.size) + dir)
    builddir = "." if builddir.empty?
  end
=end
  join = proc {|*args| File.join(*args).sub!(/\A(?:\.\/)*/, '')}
  $topdir ||= builddir
  $top_srcdir ||= (File.identical?(top_srcdir, dir = join[$topdir, srcdir]) ?
                     dir : top_srcdir)
  $extout = '$(topdir)/.ext'
  $extout_prefix = '$(extout)$(target_prefix)/'
  config = RbConfig::CONFIG
  mkconfig = RbConfig::MAKEFILE_CONFIG
  $builtruby ||= File.join(builddir, config['RUBY_INSTALL_NAME'] + config['EXEEXT'])
  RbConfig.fire_update!("builddir", builddir)
  RbConfig.fire_update!("buildlibdir", builddir)
  RbConfig.fire_update!("libdir", builddir)
  RbConfig.fire_update!("prefix", $topdir)
  RbConfig.fire_update!("top_srcdir", $top_srcdir ||= top_srcdir)
  RbConfig.fire_update!("extout", $extout)
  RbConfig.fire_update!("rubyhdrdir", "$(top_srcdir)/include")
  RbConfig.fire_update!("rubyarchhdrdir", "$(extout)/include/$(arch)")
  RbConfig.fire_update!("rubyarchdir", "$(extout)/$(arch)")
  RbConfig.fire_update!("rubylibdir", "$(extout)/common")
  RbConfig.fire_update!("libdirname", "buildlibdir")
  trace_var(:$ruby, posthook)
  untrace_var(:$extmk, prehook)
end
trace_var(:$extmk, prehook)
