package Test::MockObject::Extends;

use strict;
use warnings;

use Test::MockObject;
use Scalar::Util 'blessed';

use vars qw( $VERSION $AUTOLOAD );
$VERSION = '1.03';

sub new
{
	my ($class, $fake_class) = @_;

	return Test::MockObject->new() unless defined $fake_class;

	my $parent_class = $class->get_class( $fake_class );
	$class->check_class_loaded( $parent_class );
	my $self         = blessed( $fake_class ) ? $fake_class : {};

	bless $self, $class->gen_package( $parent_class );
}

sub check_class_loaded
{
	my ($self, $parent_class) = @_;

	my $symtable = \%main::;
	my $found    = 1;

	for my $symbol ( split( '::', $parent_class ))
	{
		unless (exists $symtable->{ $symbol . '::' })
		{
			$found = 0;
			last;
		}
		
		$symbol = $symtable->{ $symbol . '::' };
	}

	unless ($found)
	{
		(my $load_class  = $parent_class) =~ s/::/\//g;
		require $load_class . '.pm';
	}
}

sub get_class
{
	my ($self, $invocant) = @_;

	return $invocant unless blessed $invocant;
	return ref $invocant;
}

my $packname = 'a';

sub gen_package
{
	my ($class, $parent)         = @_;
	my $package                  = 'T::MO::E::' . $packname++;

	no strict 'refs';
	*{ $package . '::mock'     } = \&mock;
	*{ $package . '::unmock'   } = \&unmock;
	*{ $package . '::ISA'      } = [ $parent ];
	*{ $package . '::can'      } = $class->gen_can( $parent );
	*{ $package . '::isa'      } = $class->gen_isa( $parent );
	*{ $package . '::AUTOLOAD' } = $class->gen_autoload( $parent );

	return $package;
}

sub gen_isa
{
	my ($class, $parent)    = @_;
	
	sub
	{
		my ($self, $class) = @_;
		return 1 if $class eq $parent;
		return $parent->isa( $class );
	};
}

sub gen_can
{
	my ($class, $parent) = @_;

	sub
	{
		my ($self, $method) = @_;
		my $parent_method   = $self->SUPER::can( $method );
		return $parent_method if $parent_method;
		return Test::MockObject->can( $method );
	};
}

sub gen_autoload
{
	my ($class, $parent) = @_;

	sub
	{
		my $method = substr( $AUTOLOAD, rindex( $AUTOLOAD, ':' ) +1 );
		return if $method eq 'DESTROY';

		my $self   = shift;

		if (my $parent_method  = $parent->can( $method ))
		{
			return $self->$parent_method( @_ );
		}
		elsif (my $mock_method = Test::MockObject->can( $method ))
		{
			return $self->$mock_method( @_ );
		}
		elsif (my $parent_al = $parent->can( 'AUTOLOAD' ))
		{
			my $parent_pack  = blessed( $parent ) || $parent;
			{
				no strict 'refs';
				${ "${parent_pack}::AUTOLOAD" } = "${parent_pack}::${method}";
			}
			unshift @_, $self;
			goto &$parent_al;
		}
	};
}

sub mock
{
	my ($self, $name, $sub) = @_;

	Test::MockObject::_set_log( $self, $name, ( $name =~ s/^-// ? 0 : 1 ) );

	my $mock_sub = sub 
	{
		my ($self) = @_;
		$self->log_call( $name, @_ );
		$sub->( @_ );
	};
	
	{
		no strict 'refs';
		no warnings 'redefine';
		*{ ref( $self ) . '::' . $name } = $mock_sub;
	}

}

sub unmock
{
	my ($self, $name) = @_;

	Test::MockObject::_set_log( $self, $name, 0 );
	no strict 'refs';
	my $glob = *{ ref( $self ) . '::' };
	delete $glob->{ $name };
}

1;
__END__

=head1 NAME

Test::MockObject::Extends - mock part of an object or class

=head1 SYNOPSIS

  use Some::Class;
  use Test::MockObject::Extends;

  my $object      = Some::Class->new();
  my $mock_object = Test::MockObject::Extends->new( $object );

  $mock_object->set_true( 'parent_method' );

=head1 DESCRIPTION

Test::MockObject::Extends lets you mock one or more methods of an existing
object or class.  This can be very handy when you're testing a well-factored
module that does almost exactly what you want.  Wouldn't it be handy to take
control of a method or two to make sure you receive testable results?  Now you
can.

=head1 METHODS

=over 4

=item C<new( $object | $class )>

C<new()> takes one optional argument, the object or class to mock.  If you're
mocking a method for an object that holds internal state, create an appropriate
object, then pass it to this constructor.

If you're mocking an object that does not need state, as in the cases where
there's no internal data or you'll only be calling class methods, or where
you'll be mocking all of the access to internal data, you can pass in the name
of the class to mock partially.

If you've not yet loaded the class, this method will try to load it for you.
This may fail, so beware.

If you pass no arguments, it will assume you really meant to create a normal
C<Test::MockObject> object and will oblige you.

=item C<mock( $methodname, $sub_ref )>

See the documentation for Test::MockObject for all of the ways to mock methods
and to retrieve method logging information.

=item C<unmock( $methodname )>

Removes any active mocking of the named method.  This means any calls to that
method will hit the method of that name in the class being mocked, if it
exists.

=item C<isa( $class )>

As you'd expect from a mocked object, this will return true for the class it's
mocking.

=back

=head1 INTERNAL METHODS

To do its magic, this module uses several internal methods:

=over 4

=item * C<gen_autoload( $extended )>

Returns an AUTOLOAD subroutine for the mock object that checks that the
extended object (or class) can perform the requested method, that
L<Test::MockObject> can perform it, or that the parent has an appropriate
AUTOLOAD of its own.  (It should have its own C<can()> in that case too
though.)

=item * C<gen_can( $extended )>

Returns a C<can()> method for the mock object that respects the same execution
order as C<gen_autoload()>.

=item * C<gen_isa( $extended )>

Returns an C<isa()> method for the mock object that claims to be the
C<$extended> object appropriately.

=item * C<gen_package( $extended )>

Creates a new unique package for the mock object with the appropriate methods
already installed.

=item * C<get_class( $invocant )>

Returns the class name of the invocant, whether it's an object or a class name.

=back

=head1 CAVEATS

There may be some weird corner cases with dynamically generated methods in the
mocked class.  You really should use subroutine declarations though, or at
least set C<can()> appropriately.

There are also potential name collisions with methods in this module or
C<Test::MockObject>, though this should be rare.

=head1 AUTHOR

chromatic, E<lt>chromatic at wgz dot orgE<gt>

Documentation bug fixed by Stevan Little.  Additional AUTOLOAD approach
suggested by Adam Kennedy.

=head1 BUGS

No known bugs.

=head1 COPYRIGHT

Copyright (c) 2004 - 2006, chromatic.  All rights reserved.  You may use,
modify, and distribute this module under the same terms as Perl 5.8.x.
