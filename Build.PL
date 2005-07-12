use Module::Build;

my $build = Module::Build->new(
	module_name => 'Test::MockObject',
	license     => 'perl',
	sign        => 1,
	requires    =>
	{
		'Scalar::Util'  =>     '',
		'Test::Warn'    =>     '',
		'Test::Simple'  => '0.47',
	},
	dist_version_from   => 'lib/Test/MockObject.pm',
	create_makefile_pl  => 'traditional',
);

$build->create_build_script();
