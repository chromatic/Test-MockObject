#!/usr/bin/perl -w

BEGIN
{
	chdir 't' if -d 't';
	use lib '../lib', '../blib/lib';
}

use strict;
use Test::More tests => 13;

my $module = 'Test::MockObject::Extends';
use_ok( $module ) or exit;

my $tme = $module->new();
isa_ok( $tme, 'Test::MockObject' );

$tme    = $module->new( 'Test::Builder' );
ok( $tme->isa( 'Test::Builder' ),
	'passing a class name to new() should set inheritance properly' );

$tme = $module->new( 'File::Spec' );
ok( $INC{ File::Spec->catfile( qw( File Spec.pm ) ) },
	'new() should load parent module unless already loaded' );

package Some::Class;

@Some::Class::ISA = 'Another::Class';

sub path
{
	return $_[0]->{path};
}

sub foo
{
	return 'original';
}

sub bar
{
	return 'original';
}

package Another::Class;

package main;

# fake that we have loaded these
$INC{ File::Spec->catfile(qw( Some    Class.pm ) ) } = 1;
$INC{ File::Spec->catfile(qw( Another Class.pm ) ) } = 1;

$tme = $module->new( 'Some::Class' );
$tme->set_always( bar => 'mocked' );
is( $tme->bar(), 'mocked',   'mock() should override method in parent' );
is( $tme->foo(), 'original', '... calling original methods in parent'  );

$tme->unmock( 'bar' );
is( $tme->bar(), 'original', 'unmock() should remove method overriding' );

$tme->mock( pass_self => sub
{
	is( shift, $tme, '... and should pass along invocant' );
});

$tme->pass_self();
my ($method, $args) = $tme->next_call();
is( $method, 'bar', '... logging methods appropriately' );

my $sc      = bless { path => 'my path' }, 'Some::Class';
my $mock_sc = $module->new( $sc );
is( $mock_sc->path(), 'my path',
	'... should wrap existing object appropriately' );
isa_ok( $mock_sc, 'Some::Class' )
	or diag( '... marking isa() appropriately on mocked object' );
isa_ok( $mock_sc, 'Another::Class' )
	or diag( '... and delegating isa() appropriately on parent classes' );

ok( ! $mock_sc->isa( 'No::Class' ),
	'... returning the right result even when the class is not a parent' );
