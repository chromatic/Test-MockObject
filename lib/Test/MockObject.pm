package Test::MockObject;

use strict;

use vars qw( $VERSION $AUTOLOAD );
$VERSION = '0.03';

use Test::Builder;
my $Test = Test::Builder->new();

sub new {
	my $class = shift;
	bless {}, $class;
}

sub add {
	my ($self, $name, $sub) = @_;
	$self->{_subs}{$name} = $sub;
}

sub set_always {
	my ($self, $name, $value) = @_;
	$self->add( $name, sub { $value } );
}

sub set_true {
	my ($self, $name) = @_;
	$self->add( $name, sub { 1 } );
}

sub set_false {
	my ($self, $name) = @_;
	$self->add( $name, sub {} );
}

sub set_list {
	my ($self, $name, @list) = @_;
	$self->add( $name, sub { @{[ @list ]} } );
}

sub set_series {
	my ($self, $name, @list) = @_;
	$self->add( $name, sub { shift @list } );
}

sub can {
	my ($self, $sub) = @_;

	# mockmethods are special cases, class methods are handled directly
	return 1 if (ref $self and exists $self->{_subs}{$sub});
	return UNIVERSAL::can(@_);
}

sub remove {
	my ($self, $sub) = @_;
	delete $self->{_subs}{$sub};
}

sub called {
	my ($self, $sub) = @_;
	
	for my $called (reverse @{ $self->{_calls} }) {
		return 1 if $called->[0] eq $sub;
	}

	return;
}

sub clear {
	my $self = shift;
	$self->{_calls} = [];
}

sub call_pos {
	$_[0]->_call($_[1], 0);
}

sub call_args {
	return @{ $_[0]->_call($_[1], 1) };
}

sub _call {
	my ($self, $pos, $type) = @_;
	$pos-- if $pos > 0;
	return $self->{_calls}[$pos][$type];
}

sub call_args_string {
	my $args = $_[0]->_call( $_[1], 1 ) or return;
	return join($_[2] || '', @$args);
}

sub call_args_pos {
	my ($self, $subpos, $argpos) = @_;
	my $args = $self->_call( $subpos, 1 ) or return;
	$argpos-- if $argpos > 0;
	return $args->[$argpos];
}

sub AUTOLOAD {
	my $self = shift;
	my ($sub) = $AUTOLOAD =~ /::(\w+)\z/;
	return if $sub eq 'DESTROY';

	if (exists $self->{_subs}{$sub}) {
		push @{ $self->{_calls} }, [ $sub, \@_ ];
		goto &{ $self->{_subs}{$sub} };
	}
	return;
}

sub called_ok {
	my ($self, $sub, $name) = @_;
	$name ||= "object called '$sub'";
	$Test->ok( $self->called($sub), $name );
}

sub called_pos_ok {
	my ($self, $pos, $sub, $name) = @_;
	$name ||= "object called '$sub' at position $pos";
	$Test->ok( $self->call_pos($pos, $sub), $name );
}

sub called_args_string_is {
	my ($self, $pos, $sep, $expected, $name) = @_;
	$name ||= "object sent expected args to sub at position $pos";
	$Test->is_eq( $self->call_args_string( $pos, $sep ), $expected, $name );
}

sub called_args_pos_is {
	my ($self, $pos, $argpos, $arg, $name) = @_;
	$name ||= "object sent expected arg '$arg' to sub at position $pos";
	$Test->is_eq( $self->call_args_pos( $pos, $argpos ), $arg, $name );
}

sub fake_module {
	my ($class, $modname) = @_;
	$modname =~ s!::!/!g;
	$ENV{ $modname . '.pm' } = 1;
}

sub fake_new {
	my ($self, $class) = @_;
	no strict 'refs';
	*{ $class . '::new' } = sub { $self };
}

1;
__END__

=head1 NAME

Test::MockObject - Perl extension for emulating troublesome interfaces

=head1 SYNOPSIS

  use Test::MockObject;
  my $mock = Test::MockObject->new();
  $mock->set_true( 'somemethod' );
  ok( $mock->somemethod );

=head1 DESCRIPTION

It's a simple program that doesn't use any other modules, and those are easy to
test.  More often, testing a program completely means faking up input to
another module, trying to coax the right output from something you're not
supposed to be testing anyway.

Testing is a lot easier when you can control the entire environment.  With
Test::MockObject, you can get a lot closer.

Test::MockObject allows you to create objects that conform to particular
interfaces with very little code.  You don't have to reimplement the behavior,
just the input and the output.

=head2 EXPORT

None by default.  Maybe the Test::Builder accessories, in a future version.

=head2 FUNCTIONS

The most important thing a Mock Object can do is to conform sufficiently to an
interface.  For example, if you're testing something that relies on CGI.pm, you
may find it easier to create a mock object that returns controllable results
at given times than to fake query string input.

=over 4

=item * C<new>

Creates a new mock object.  Currently, this is a blessed hash.  In the future,
there may be support for different types of objects.

=item * C<add(I<name>, I<coderef>)>

Adds a coderef to the object.  This allows the named method to be called on the
object.  For example, this code:

	my $mock = Test::MockObject->new();
	$mock->add('fluorinate', 
		sub { 'impurifying precious bodily fluids' });
	print $mock->fluorinate;

will print a helpful warning message.  Please note that methods are only added
to a single object at a time and not the class.  (There is no small similarity
to the Self programming language, or the Class::Prototyped module.)

This method forms the basis for most of Test::MockObject's testing goodness.

=item * C<set_always(I<name>, I<value>)>

Adds a method of the specified name that always returns the specified value.

=item * C<set_true(I<name>)>

Adds a method of the specified name that always returns a true value.

=item * C<set_false(I<name>)>

Adds a method of the specified name that always returns a false value.  (Since
it installs an empty subroutine, the value should be false in both scalar and
list contexts.)

=item * C<set_list(I<name>, [ I<item1>, I<item2>, ... ]>

Adds a method that always returns a given list of values.  It takes some care
to provide a list and not an array, if that's important to you.

=item * C<set_series(I<name>, [ I<item1>, I<item2>, ... ]>

Adds a method that will return the next item in a series on each call.  This
cam be an effective way to test error handling, by forcing a failure on the
first method call and then subsequent successes.  Note that the series is
(eventually) destroyed.

=item * C<remove(I<name>)>

Removes a named method.

=item * C<called(I<name>)>

Checks to see if a named method has been called on the object.  This returns a
boolean value.  The current implementation does not scale especially well, so
use this sparingly if you need to search through hundreds of calls.

=item * C<clear()>

Clears the internal record of all method calls on the object.  It's handy to do
this every now and then.

=item * C<call_pos(I<position>)>

Returns the name of the method called on the object at a specified position.
This is handy if you need to test a certain order of calls.  For example:

	Some::Function( $mock );
	is( $mock->call_pos(1),  'setup',
		'Function() should first call setup()' );
	is( $mock->call_pos(-1), 'end', 
		'... and last call end()' );

Positions can be positive or negative.  Please note that the first position is,
in fact, 1.  (This may change in the future.  I like it, but am willing to
reconsider.)

=item * C<call_args(I<position>)>

Returns a list of the arguments provided to the method called at the appropriate
position.  Following the test above, one might say:

	is( ($mock->call_args(1))[0], $mock,
		'... passing the object to setup()' );
	is( scalar $mock->call_args(-1), 0,
		'... and no args to end()' );

=item * C<call_args_pos(I<call position>, I<argument position>)>

Returns the argument at the specified position for the method call at the
specified position.  One might rewrite the first test of the last example as:

	is( $mock->call_args_pos(1, 1), $mock,
		'... passing the object to setup()');

=item * C<call_args_string(I<position>, [ I<separator> ])>

Returns a stringified version of the arguments at the specified position.  If
no separator is given, they will not be separated.  This can be used as:

	is( $mock->call_args_string(1), "$mock initialize",
		'... passing object and initialize as its arguments' );

=item * C<fake_module(I<module name>)>

Lies to Perl that a named module has already been loaded.  This is handy when
providing a mockup of a real module if you'd like to prevent the actual module
from interfering with the nice fakery.  If you're mocking L<Regexp::English>,
say:

	$mock->fake_module( 'Regexp::English' );

This can be invoked both as a class and as an object method.  Beware that this
must take place before the actual module has a chance to load.  Either wrap it
in a BEGIN block before a use or require, or place it before a C<use_ok()> or
C<require_ok()> call.

=item * C<fake_new(I<module name>)>

Provides a fake constructor for the given module that returns the invoking mock
object.  Used in conjunction with C<fake_module()>, you can force the tested
unit to work with the mock object instead.

	$mock->fake_module( 'CGI' );
	$mock->fake_new( 'CGI' );

	use_ok( 'Some::Module' );
	my $s = Some::Module->new();
	is( $s->{_cgi}, $mock,
		'new() should create and store a new CGI object' );

=item * C<called_ok(I<method name>, [ I<test name> ])>

Tests to see whether a method of the specified name has been called on the
object.  This and the following methods use Test::Builder, so they integrate
nicely with a test suite built around Test::Simple, Test::More, or anything
else compatible:

	$mock->foo();
	$mock->called_ok( 'foo' );

A generic default test name is provided.

=item * C<called_pos_ok(I<position>, I<method name>, [ I<test name> ])>

Tests to see whether the named method was called at the specified position.  A
default test name is provided.

=item * C<called_args_pos_is(I<method position>, I<argument position>, I<expected>, [ I<test name> ])>

Tests to see whether the argument at the appropriate position of the method in
the specified position equals a specified value.  A default, rather
non-descript test name is provided.

=item * C<called_args_string_is(I<method position>, I<separator>, I<expected>, [ I<test name> ])>

Joins together all of the arguments to a method at the appropriate position and
matches against a specified string.  A generically bland test name is provided
by default.  You can probably do much better.

=back

=head1 TODO

=over 4

=item * Write an article about how to use this and why :)

=item * Handle C<isa()>

=item * Make C<fake_module()> and C<fake_new()> undoable

=item * Allow different types of blessed referents

=item * Add more useful methods (catch C<import()>?)

=back

=head1 AUTHOR

chromatic, E<lt>chromatic@wgz.orgE<gt>

=head1 SEE ALSO

L<perl>, L<Test::Tutorial>, L<Test::More>.

=head1 COPYRIGHT

Copyright 2002 by chromatic E<lt>chromatic@wgz.orgE<gt>.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
