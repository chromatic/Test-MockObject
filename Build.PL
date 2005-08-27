use Module::Build;

my $build = Module::Build->new(
	module_name => 'Test::MockObject',
	license     => 'perl',
	sign        => 1,
	requires    =>
	{
		'Scalar::Util'    =>     '',
		'Test::Simple'    => '0.47',
		'UNIVERSAL::isa'  => '0.02',
		'UNIVERSAL::can'  => '1.00',
	},
	build_requires =>
	{
		'Test::Warn'      =>     '',
		'Test::Exception' =>     '',
	},
	dist_version_from   => 'lib/Test/MockObject.pm',
	create_makefile_pl  => 'traditional',
);

$build->create_build_script();
