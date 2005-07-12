package Test::MockObject;

use strict;

use vars qw( $VERSION $AUTOLOAD );
$VERSION = '0.11';

use Test::Builder;
my $Test = Test::Builder->new();
my (%calls, %subs);

sub new
{
	my ($class, $type) = @_;
	$type ||= {};
	bless $type, $class;
}

sub mock
{
	my ($self, $name, $sub) = @_;
	$sub ||= sub {};
	_subs( $self )->{$name} = $sub;
	$self;
}

# deprecated and complicated as of 0.07
sub add
{
	my $self = shift;
	my $subs = _subs( $self );
	return $subs->{add}->( $self, @_ )
		 if (exists $subs->{add} and !( UNIVERSAL::isa( $_[1], 'CODE' )));
	$self->mock( @_ );
}

sub set_always
{
	my ($self, $name, $value) = @_;
	$self->mock( $name, sub { $value } );
}

sub set_true
{
	my ($self, $name) = @_;
	$self->mock( $name, sub { 1 } );
}

sub set_false
{
	my ($self, $name) = @_;
	$self->mock( $name, sub {} );
}

sub set_list
{
	my ($self, $name, @list) = @_;
	$self->mock( $name, sub { @{[ @list ]} } );
}

sub set_series
{
	my ($self, $name, @list) = @_;
	$self->mock( $name, sub { return unless @list; shift @list } );
}

sub set_bound
{
	my ($self, $name, $ref) = @_;
	my $code;
	if (UNIVERSAL::isa( $ref, 'SCALAR' ))
	{
		$code = sub { $$ref };
	}
	elsif (UNIVERSAL::isa( $ref, 'ARRAY' ))
	{
		$code = sub { @$ref };
	}
	elsif (UNIVERSAL::isa( $ref, 'HASH' ))
	{
		$code = sub { %$ref };
	}
	$self->mock( $name, $code );
}

sub can
{
	my ($self, $sub) = @_;

	# mockmethods are special cases, class methods are handled directly
	my $subs = _subs( $self );
	return $subs->{$sub} if (ref $self and exists $subs->{$sub});
	return UNIVERSAL::can(@_);
}

sub remove
{
	my ($self, $sub) = @_;
	delete _subs( $self )->{$sub};
	$self;
}

sub called
{
	my ($self, $sub) = @_;
	
	for my $called (reverse @{ _calls( $self ) }) {
		return 1 if $called->[0] eq $sub;
	}

	return;
}

sub clear
{
	my $self  = shift;
	@{ _calls( $self ) } = ();
	$self;
}

sub call_pos
{
	$_[0]->_call($_[1], 0);
}

sub call_args
{
	return @{ $_[0]->_call($_[1], 1) };
}

sub _call
{
	my ($self, $pos, $type) = @_;
	my $calls = _calls( $self );
	return if abs($pos) > @$calls;
	$pos-- if $pos > 0;
	return $calls->[$pos][$type];
}

sub call_args_string
{
	my $args = $_[0]->_call( $_[1], 1 ) or return;
	return join($_[2] || '', @$args);
}

sub call_args_pos
{
	my ($self, $subpos, $argpos) = @_;
	my $args = $self->_call( $subpos, 1 ) or return;
	$argpos-- if $argpos > 0;
	return $args->[$argpos];
}

sub next_call
{
	my ($self, $num) = @_;
	$num ||= 1;

	my $calls = _calls( $self );
	return unless @$calls >= $num;

	my ($call) = (splice(@$calls, 0, $num))[-1];
	return wantarray() ? @$call : $call->[0];
}

sub AUTOLOAD
{
	my $self = $_[0];
	my $sub;
	{
		local $1;
		($sub) = $AUTOLOAD =~ /::(\w+)\z/;
	}
	return if $sub eq 'DESTROY';

	my $subs = _subs( $self );
	if (exists $subs->{$sub})
	{
		push @{ _calls( $self ) }, [ $sub, [ @_ ] ];
		goto &{ $subs->{$sub} };
	}
	else
	{
		require Carp;
		Carp::carp("Un-mocked method '$sub()' called");
	}
	return;
}

sub called_ok
{
	my ($self, $sub, $name) = @_;
	$name ||= "object called '$sub'";
	$Test->ok( $self->called($sub), $name );
}

sub called_pos_ok
{
	my ($self, $pos, $sub, $name) = @_;
	$name ||= "object called '$sub' at position $pos";
	my $called = $self->call_pos($pos, $sub);
	unless ($Test->ok( (defined $called and $called eq $sub), $name )) {
		$called = 'undef' unless defined $called;
		$Test->diag("Got:\n\t'$called'\nExpected:\n\t'$sub'\n");
	}
}

sub called_args_string_is
{
	my ($self, $pos, $sep, $expected, $name) = @_;
	$name ||= "object sent expected args to sub at position $pos";
	$Test->is_eq( $self->call_args_string( $pos, $sep ), $expected, $name );
}

sub called_args_pos_is
{
	my ($self, $pos, $argpos, $arg, $name) = @_;
	$name ||= "object sent expected arg '$arg' to sub at position $pos";
	$Test->is_eq( $self->call_args_pos( $pos, $argpos ), $arg, $name );
}

sub fake_module
{
	my ($class, $modname, %subs) = @_;
	$modname =~ s!::!/!g;
	$INC{ $modname . '.pm' } = 1;

	local $SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };
	no strict 'refs';
	${ $modname . '::' }{VERSION} ||= -1;
	
	foreach my $sub (keys %subs) {
		unless (UNIVERSAL::isa( $subs{ $sub }, 'CODE')) {
			require Carp;
			Carp::carp("'$sub' is not a code reference" );
			next;
		}
		*{ $_[1] . '::' . $sub } = $subs{ $sub };
	}
}

sub fake_new
{
	my ($self, $class) = @_;
	$self->fake_module( $class, new => sub { $self } );
}

{
	my %calls;

	sub _calls
	{
		my $key = shift;
		$calls{ $key } ||= [];
	}
}

{
	my %subs;

	sub _subs
	{
		my $key = shift;
		$subs{ $key } ||= {};
	}
}

1;

__END__

=head1 NAME

Test::MockObject - Perl extension for emulating troublesome interfaces

=head1 SYNOPSIS

  use Test::MockObject;
  my $mock = Test::MockObject->new();
  $mock->set_true( 'somemethod' );
  ok( $mock->somemethod() );

  $mock->set_true( 'veritas')
  	   ->set_false( 'ficta' )
	   ->set_series( 'amicae', 'Sunny', 'Kylie', 'Bella' );

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

=head2 IMPORTANT CAVEAT FOR TESTERS

Please note that it is possible to write highly detailed unit tests that pass
even when your integration tests may fail.  Testing the pieces individually
does not excuse you from testing the whole thing together.  I consider this to
be a feature.

=head2 EXPORT

None by default.  Maybe the Test::Builder accessories, in a future version.

=head2 FUNCTIONS

The most important thing a Mock Object can do is to conform sufficiently to an
interface.  For example, if you're testing something that relies on CGI.pm, you
may find it easier to create a mock object that returns controllable results
at given times than to fake query string input.

B<The Basics>

=over 4

=item * C<new>

Creates a new mock object.  By default, this is a blessed hash.  Pass a
reference to bless that reference.

	my $mock_array  = Test::MockObject->new( [] );
	my $mock_scalar = Test::MockObject->new( \( my $scalar ) );
	my $mock_code   = Test::MockObject->new( sub {} );
	my $mock_glob   = Test::MockObject->new( \*GLOB );

=back

B<Mocking>

Your mock object is nearly useless if you don't tell it what it's mocking.
This is done by installing methods.  You control the output of these mocked
methods.  In addition, any mocked method is tracked.  You can tell not only
what was called, but which arguments were passed.  Please note that you cannot
track non-mocked method calls.  They will still be allowed, though
Test::MockObject will carp() about them.  This is considered a feature, though
it may be possible to disable this in the future.

As implied in the example above, it's possible to chain these calls together.
Thanks to a suggestion from the fabulous Piers Cawley (CPAN RT #1249), this
feature came about in version 0.09.  Shorter testing code is nice!

=over 4

=item * C<mock(I<name>, I<coderef>)>

Adds a coderef to the object.  This allows the named method to be called on the
object.  For example, this code:

	my $mock = Test::MockObject->new();
	$mock->mock('fluorinate', 
		sub { 'impurifying precious bodily fluids' });
	print $mock->fluorinate;

will print a helpful warning message.  Please note that methods are only added
to a single object at a time and not the class.  (There is no small similarity
to the Self programming language, or the Class::Prototyped module.)

This method forms the basis for most of Test::MockObject's testing goodness.

B<Please Note:> this method used to be called C<add()>.  Due to its ambiguity,
it is now spelled differently.  For backwards compatibility purposes, add() is
available, though deprecated as of version 0.07.  It goes to some contortions
to try to do what you mean, but I make few guarantees.

=item * C<fake_module(I<module name>), [ I<subname> => I<coderef>, ... ]

Lies to Perl that a named module has already been loaded.  This is handy when
providing a mockup of a real module if you'd like to prevent the actual module
from interfering with the nice fakery.  If you're mocking L<Regexp::English>,
say:

	$mock->fake_module( 'Regexp::English' );

This can be invoked both as a class and as an object method.  Beware that this
must take place before the actual module has a chance to load.  Either wrap it
in a BEGIN block before a use or require, or place it before a C<use_ok()> or
C<require_ok()> call.

You can optionally add functions to the mocked module by passing them as name
=> coderef pairs to C<fake_module()>.  This is handy if you want to test an
import():

	my $import;
	$mock->fake_module(
		'Regexp::English',
		import => sub { $import = caller }
	);
	use_ok( 'Regexp::Esperanto' );
	is( $import, 'Regexp::Esperanto',
		'Regexp::Esperanto should use() Regexp::English' );

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
can be an effective way to test error handling, by forcing a failure on the
first method call and then subsequent successes.  Note that the series is
(eventually) destroyed.

=item * C<set_bound(I<name>, I<reference>)>

Adds a method bound to a variable.  Pass in a reference to a variable in your
test.  When you change the variable, the return value of the new method will
change as well.  This is often handier than replacing mock methods.

=item * C<remove(I<name>)>

Removes a named method.

=back

B<Checking Your Mocks>

=over 4

=item * C<called(I<name>)>

Checks to see if a named method has been called on the object.  This returns a
boolean value.  The current implementation does not scale especially well, so
use this sparingly if you need to search through hundreds of calls.

=item * C<clear()>

Clears the internal record of all method calls on the object.  It's handy to do
this every now and then.

=item * C<next_call([ I<position> ])>

Returns the name and argument list of the next mocked method that was called on
an object, in list context.  In scalar context, returns only the method name.
There are two important things to know about this method.  First, it starts at
the beginning of the call list.  If your code runs like this:

	$mock->set_true( 'foo' );
	$mock->set_true( 'bar' );
	$mock->set_true( 'baz' );

	$mock->foo();
	$mock->bar( 3, 4 );
	$mock->foo( 1, 2 );

Then you might get output of:

	my ($name, $args) = $mock->next_call();
	print "$name (@$args)";

	# prints 'foo'

	$name = $mock->next_call();
	print $name;

	# prints 'bar'

	($name, $args) = $mock->next_call();
	print "$name (@$args)";

	# prints 'foo 1 2'

If you provide an optional number as the I<position> argument, the method will
skip that many calls, returning the data for the last one skipped.

	$mock->foo();
	$mock->bar();
	$mock->baz();

	$name = $mock->next_call();
	print $name;

	# prints 'foo'

	$name = $mock->next_call( 2 );
	print $name

	# prints 'baz'

When it reaches the end of the list, it returns undef.  This is probably the
most convenient method in the whole module, but for the sake of completeness
and backwards compatibility (it takes me a while to reach the truest state of
laziness!), there are several other methods.

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
		'... passing object, initialize as arguments' );

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

=item * Add a factory method to avoid namespace collisions (soon)

=item * Handle C<isa()>

=item * Make C<fake_module()> and C<fake_new()> undoable

=item * Add more useful methods (catch C<import()>?)

=item * Move C<fake_module()> and C<fake_new()> into a Test::MockModule

=back

=head1 AUTHOR

chromatic, E<lt>chromatic@wgz.orgE<gt>

Thanks go to Curtis 'Ovid' Poe, as well as ONSITE! Technology, Inc., for
finding several bugs and providing several constructive suggestions.

=head1 SEE ALSO

L<perl>, L<Test::Tutorial>, L<Test::More>,
L<http:E<sol>E<sol>www.perl.comE<sol>pubE<sol>aE<sol>2001E<sol>12E<sol>04E<sol>testing.html>.

=head1 COPYRIGHT

Copyright 2002 - 2003 by chromatic E<lt>chromatic@wgz.orgE<gt>.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
