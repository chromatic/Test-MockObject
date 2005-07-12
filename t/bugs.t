#!/usr/bin/perl -w

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib';
}

use strict;
use Test::More 'no_plan';

use Test::MockObject;
my $mock = Test::MockObject->new();

{
	local $@ = '';
	eval { $mock->called( 1, 'foo' ) };
	my $stack = $mock->{_calls};
	is( $@, '', 'called() should not die from no array ref object' );
	isa_ok( $stack, 'ARRAY', 'new() should create an empty call stack which' );
}

{
	$mock->{_calls} = [ 1 .. 4 ];
	$mock->_call( 5 );
	is( @{ $mock->{_calls} }, 4,
		'_call() should not autovivify extra calls on the stack' );
}

{
	my $warn = '';
	local $SIG{__WARN__} = sub {
		$warn = shift;
	};
	$mock->fake_module( 'Foo', bar => sub {} );
	$mock->fake_module( 'Foo', bar => sub {} );
	is( $warn, '', 'fake_module() should catch redefined sub warnings' );
}

my ($ok, $warn, @diag);
{
	local (*Test::Builder::ok, *Test::Builder::diag);
	*Test::Builder::ok = sub {
		$ok = $_[1];
	};

	*Test::Builder::diag = sub {
		push @diag, $_[1];
	};
	$mock->{_calls} = [ [ 4, 4 ], [ 5, 5 ] ];

	$mock->called_pos_ok( 2, 8 );

	local $SIG{__WARN__} = sub {
		$warn = shift;
	};

	$mock->called_pos_ok( 888, 'foo' );
}
ok( ! $ok, 'called_pos_ok() should return false if name does not match' );
like( $diag[0], qr/Got.+Expected/s, '... printing a helpful diagnostic' );
unlike( $warn, qr/uninitialized value/,
	'called_pos_ok() should not throw uninitialized value warnings on failure');
like( $diag[1], qr/'undef'/, '... faking it with the word in the error' );

$mock->clear();
$mock->set_true( 'foo' );
my $result;
$_ = 'bar';
if (/(\w+)/) {
	$mock->foo( $1 );
}
is( $mock->call_args_pos( -1, 2 ), 'bar', 
	'$1 should be preserved through AUTOLOAD invocation' );

$mock->fake_module( 'fakemodule' );
{
	no strict 'refs';
	ok( %{ 'fakemodule::' },
		'fake_module() should create a symbol table entry for the module' );
}
