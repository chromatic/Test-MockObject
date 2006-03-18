use Module::Build;

my $class = Module::Build->subclass(
	class => 'Module::Build::FilterTests',
	code  => <<'END_HERE',
	
	use File::Glob;
	use File::Spec::Functions;
	
	sub ACTION_disttest
	{
		my $self = shift;
		local $ENV{PERL_RUN_ALL_TESTS} = 1;
		$self->SUPER::ACTION_disttest( @_ );
	}
	
	sub find_test_files
	{
		my $self  = shift;
		my $tests = $self->SUPER::find_test_files( @_ );
	    
		return $tests unless $ENV{PERL_RUN_ALL_TESTS};
	
		my $test_pattern = catfile(qw( t developer *.t ) );
		push @$tests, File::Glob::bsd_glob( $test_pattern );
		return $tests;
	}
END_HERE
);


my $build = $class->new(
	module_name => 'Test::MockObject',
	license     => 'perl',
	sign        => 1,
	requires    =>
	{
		'perl'            => '5.6.0',
		'Scalar::Util'    =>     '',
		'Test::Simple'    => '0.47',
		'UNIVERSAL::isa'  => '0.06',
		'UNIVERSAL::can'  => '1.11',
	},
	build_requires =>
	{
		'Test::Exception' =>     '',
	},
	dist_version_from   => 'lib/Test/MockObject.pm',
	create_makefile_pl  => 'traditional',
);

$build->create_build_script();
