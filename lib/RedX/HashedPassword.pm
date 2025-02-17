use v6;

need Red::Attr::Column;
use Crypt::Libcrypt:ver<0.1.0+>;

=begin pod

=head1 NAME

RedX::HashedPassword - store and use hashed passwords in the database

=head1 SYNOPSIS

=begin code

use Red;
use RedX::HashedPassword;

model User {
    has Int $.id        is serial;
    has Str $.username  is column;
    has Str $.password  is hashed-password handles <check-password>;
}

...

User.^create( username => 'user', password => 'password'); # password is saved as a hash

...

my User $user = User.^rs.first( *.username eq 'user' );

$user.check-password('password');  # True


=end code

=head1 DESCRIPTION

This provides a mechanism for L<Red|https://github.com/FCO/Red> to store a password
as a cryptographic hash in the database, such that someone who gains access to the
database cannot see the plain text password that may have been entered by a user.

The primary interface provided is the C<is hashed-password> trait that should be
applied to the column attribute in your model definition that you want to store the
hashed password in, this takes care of hashing the password before it is stored in
the database, on retrieval ("inflation") it also applies a role that provides a method
C<check-password> that checks a provided plaintext password against the stored hash.
You can make this appear to be a method of your (for example,) User model by applying
the C<handles <check-password>> trait to your column attribute.

The hashing algorithm used will be the best one provided by C<libcrypt>
( via L<Crypt::Libcrypt|https://github.com/jonathanstowe/Crypt-Libcrypt> ) or, if that
can't be determined, it will fall back to SHA-512 which seems to be the best commonly
provided algorithm.


=end pod

module RedX::HashedPassword {

    my role CryptedPasswordColumn {
        method check-password(Str $password --> Bool ) {
            crypt($password, self.Str) eq self.Str
        }
    }

    sub generate-salt(--> Str) {
        if crypt-generate-salt() -> $salt {
            $salt;
        }
        else {
            '$6$' ~ (|("a" .. "z"), |("A" .. "Z"), |(0 .. 9)).pick(16).join ~ '$';
        }
    }

    sub deflate(Str $password is raw --> Str) {
        if $password !~~ CryptedPasswordColumn  {
            $password = crypt($password, generate-salt()) but CryptedPasswordColumn;
        }
        else {
            $password;
        }
    }

    sub inflate(Str $password) {
        $password but CryptedPasswordColumn
    }

    multi sub trait_mod:<is> ( Attribute $attr, :$password! --> Empty ) is export {
        $attr does Red::Attr::Column({ :&inflate, :&deflate });
    }
}
# vim: expandtab shiftwidth=4 ft=perl6
