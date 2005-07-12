#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../lib';
}

use Test::More tests => 62;
use_ok( 'Test::MockObject' );

# new()
can_ok( 'Test::MockObject', 'new' );
my $mock = Test::MockObject->new();
isa_ok( $mock, 'Test::MockObject' );

# add()
can_ok( 'Test::MockObject', 'add' );
$mock->add('foo');
can_ok( $mock, 'foo' );

# remove()
can_ok( 'Test::MockObject', 'remove' );
$mock->remove('foo');
ok( ! $mock->can('foo'), 'remove() should remove a sub from potential action' );

# this is used for a couple of tests
sub foo { 'foo' }

$mock->add('foo', \&foo);
local $@;
my $fooput = eval{ $mock->foo() };
is( $@, '', 'add() should install callable subref' );
is( $fooput, 'foo', '... which behaves normally' );

is( $mock->can('foo'), \&foo, 'can() should return a subref' );

can_ok( 'Test::MockObject', 'set_always' );
$mock->set_always( 'bar', 'bar' );
is( $mock->bar(), 'bar', 
	'set_always() should add a sub that always returns its value' );
is( $mock->bar(), 'bar', '... so it should at least do it twice in a row' );

can_ok( 'Test::MockObject', 'set_true' );
$mock->set_true( 'blah' );
ok( $mock->blah(), 'set_true() should install a sub that returns true' );

can_ok( 'Test::MockObject', 'set_false' );
$mock->set_false( 'bloo' );
ok( ! $mock->bloo(), 'set_false() should install a sub that returns false' );
my @false = $mock->bloo();
ok( ! @false, '... even in list context' );

can_ok( 'Test::MockObject', 'set_list' );
$mock->set_list( 'baz', ( 4 .. 6 ) );
is( scalar $mock->baz(), 3, 'set_list() should install a sub to return a list');
is( join('-', $mock->baz()), '4-5-6',
	'... and the sub should always return the list' );

can_ok( 'Test::MockObject', 'set_series' );
$mock->set_series( 'amicae', 'Sunny', 'Kylie', 'Isabella' );
is( $mock->amicae(), 'Sunny',
	'set_series() should install a sub to return a series' );
is( $mock->amicae(), 'Kylie', '... in order' );
is( $mock->amicae(), 'Isabella', '... through the series' );
ok( ! $mock->amicae(), '... but false when finishing the series' );

can_ok( 'Test::MockObject', 'called' );
$mock->foo();
ok( $mock->called('foo'),
	'called() should report true if named sub was called' );
ok( ! $mock->called('notfoo'), '... and false if it was not' );

can_ok( 'Test::MockObject', 'clear' );
$mock->clear();
is( scalar @{ $mock->{_calls} }, 0,
	'clear() should clear recorded call stack' );

can_ok( 'Test::MockObject', 'call_pos' );
$mock->foo(1, 2, 3);
$mock->bar([ foo ]);
$mock->baz($mock, 88);
is( $mock->call_pos(1), 'foo', 
	'call_pos() should report name of sub called by position' );
is( $mock->call_pos(-1), 'baz', '... and should handle negative numbers' );

can_ok( 'Test::MockObject', 'call_args' );
my ($arg) = ($mock->call_args(2))[1];
is( $arg->[0], 'foo',
	'call_args() should return args for sub called by position' );
is( ($mock->call_args(2))[0], $mock,
	'... with the object as the first argument' );

can_ok( 'Test::MockObject', 'call_args_string' );
is( $mock->call_args_string(1, '-'), "$mock-1-2-3",
	'call_args_string() should return args joined' );
is( $mock->call_args_string(1), "${mock}123", '... with no default separator' );

can_ok( 'Test::MockObject', 'call_args_pos' );
is( $mock->call_args_pos(3, 1), $mock,
	'call_args_argpos() should return argument for sub by position' );
is( $mock->call_args_pos(-1, -1), 88,
	'... handing negative positions equally well' );

can_ok( 'Test::MockObject', 'called_ok' );
$mock->called_ok( 'foo' );

can_ok( 'Test::MockObject', 'called_pos_ok' );
$mock->called_pos_ok( 1, 'foo' );

can_ok( 'Test::MockObject', 'called_args_string_is' );
$mock->called_args_string_is( 1, '-', "$mock-1-2-3" );

can_ok( 'Test::MockObject', 'called_args_pos_is' );
$mock->called_args_pos_is( 1, -1, 3 );

can_ok( 'Test::MockObject', 'fake_module' );
$mock->fake_module( 'Some::Module' );
is( $INC{'Some/Module.pm'}, 1, 
	'fake_module() should prevent a module from being loaded' );

my @imported;
$mock->fake_module( 'import::me', import => sub { push @imported, $_[0] });
eval { import::me->import() };
is( $imported[0], 'import::me',
	'fake_module() should install functions in new package namespace' );
{
	my $warn;
	local $SIG{__WARN__} = sub {
		$warn = shift;
	};

	$mock->fake_module( 'badimport', foo => 'bar' );
	like( $warn, qr/'foo' is not a code reference/,
		'... and should carp if it does not receive a function reference' );
}

can_ok( 'Test::MockObject', 'fake_new' );
$mock->fake_new( 'Some::Module' );
is( Some::Module->new(), $mock, 
	'fake_new() should create a fake constructor to return mock object' );

can_ok( 'Test::MockObject', 'set_bound' );
$arg = 1;
$mock->set_bound( 'bound', \$arg );
is( $mock->bound(), 1, 'set_bound() should bind to a scalar reference' );
$arg = 2;
is( $mock->bound(), 2, '... and its return value should change with the ref' );
$arg = [ 3, 5, 7 ];
$mock->set_bound( 'bound_array', $arg );
is( join('-', $mock->bound_array()), '3-5-7', '... handling array refs' );
$arg = { foo => 'bar' };
$mock->set_bound( 'bound_hash', $arg );
is( join('-', $mock->bound_hash()), 'foo-bar', '... and hash refs' );
