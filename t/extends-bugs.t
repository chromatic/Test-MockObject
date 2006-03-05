#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 6;
use Test::Exception;

my $module = 'Test::MockObject::Extends';
use_ok( $module ) or exit;

diag( 'RT #17692 - cannot mock inline package without new()' );

{ package InlinePackageNoNew; sub foo; }

lives_ok { Test::MockObject::Extends->new( 'InlinePackageNoNew' ) }
	'Mocking a package defined inline should not load anything';

diag( 'RT #15446 - isa() ignores type of blessed reference' );

# fake that Foo is loaded
$INC{'Foo.pm'} = './Foo.pm';

# create object
my $obj = bless {}, "Foo";

# test if the object is a reference to a hash

# silence warnings with UNIVERSAL::isa and Sub::Uplevel
no warnings 'uninitialized';
ok( $obj->isa( 'HASH' ), 'The object isa HASH' );
ok( UNIVERSAL::isa( $obj, 'HASH' ),
	'...also if UNIVERSAL::isa() is called as a function' );

# wrap in mock object
Test::MockObject::Extends->new( $obj );

# test if the mock object is still a reference to a hash
ok( $obj->isa( 'HASH' ), 'The extended object isa HASH' );
ok( UNIVERSAL::isa( $obj, 'HASH' ),
	"...also if UNIVERSAL::isa() is called as a function" );
