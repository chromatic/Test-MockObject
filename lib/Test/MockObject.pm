package Test::MockObject;

use strict;

use vars qw( $VERSION $AUTOLOAD );
$VERSION = '0.02';

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

sub call_number {
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
	return join($_[2], @$args);
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

sub called_number_ok {
	my ($self, $pos, $sub, $name) = @_;
	$name ||= "object called '$sub' at position $pos";
	$Test->ok( $self->call_number($pos, $sub), $name );
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
another module, trying to get coax the right output from something you're not
supposed to be testing anyway.

Testing is a lot easier when you can control the entire environment.  With
Test::MockObject, you can get a lot closer.

Test::MockObject allows you to create objects that conform to particular
interfaces with very little code.  You don't have to reimplement the behavior,
just the input and the output.

=head2 EXPORT

None by default.  Maybe the L<Test::Builder> accessories, in a future version.

=head2 FUNCTIONS

The most important thing a Mock Object can do is to conform sufficiently to an
interface.  For example, if you're testing something that relies on CGI.pm, you
may find it easier to create a mock object that returns controllable results
at given times than to fake query string input.

=head1 AUTHOR

chromatic, E<lt>chromatic@wgz.org<gt>

=head1 SEE ALSO

L<perl>, L<Test::Tutorial>, L<Test::More>.

=cut
