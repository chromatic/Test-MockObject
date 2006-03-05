#!/usr/bin/perl

use strict;
use warnings;
use Scalar::Util qw(weaken);

use Test::More tests => 17;

use Test::MockObject;
my $mock = Test::MockObject->new();

{
	local $@ = '';
	eval { $mock->called( 1, 'foo' ) };
	is( $@, '', 'called() should not die from no array ref object' );
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

my ($ok, $warn, @diag) = ('') x 2;
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

# respect list context at the end of a series
$mock->set_series( count => 2, 3 );
my $i;
while (my ($count) = $mock->count())
{
	$i++;
	last if $i > 2;
}

is( $i, 2, 'set_series() should return false at the end of a series' );

# Jay Bonci discovered false positives in called_ok() in 0.11
{
	local *Test::Builder::ok;
	*Test::Builder::ok = sub {
		$_[1];
	};

	my $new_mock = Test::MockObject->new();
	$result = $new_mock->called_ok( 'foo' );
}

is( $result, 0, 'called_ok() should not report false positives' );

package Override;

my $id = 'default';

use base 'Test::MockObject';
use overload '""' => sub { return $id };

package main;

my $o = Override->new();
$o->set_always( foo => 'foo' );

is( "$o", 'default',  'default overloadings should work' );
$id = 'my id';
is( "$o", 'my id',    '... and not be static' );
is( $o->foo(), 'foo', '... but should not interfere with method finding' );

# no overload '""';

# David Pisoni found memory leak condition
{
	# Setup MOs with 2 references
	my ($obj1, $obj2, $obj1prime, $obj2prime);
	$obj1 = $obj1prime = Test::MockObject->new();
	$obj2 = $obj2prime = Test::MockObject->new();

	# Weaken one of the references each
	weaken $obj1prime;
	weaken $obj2prime;

	# test for memory leak condition
	$obj1->set_true('this');
	$obj1->this($obj2);

	undef $obj2;

	is( ref($obj2prime), 'Test::MockObject',
		'MO cached by another MO log should not be garbage collected' );
	undef $obj1;

	ok( !ref($obj2prime), '... but should go away when caching MO does' );

	ok( !ref($obj1prime),
		'... and the caching MO better go away too!' );
}
