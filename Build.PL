use Module::Build;

my $build = Module::Build->new(
	module_name => 'Test::MockObject',
	license     => 'perl',
	sign        => 1,
	requires    =>
	{
		'Scalar::Util'  => '',
		'Test::Simple'  => '0.47',
	},
	dist_version_from   => 'lib/Test/MockObject.pm',
);

$build->create_build_script();
