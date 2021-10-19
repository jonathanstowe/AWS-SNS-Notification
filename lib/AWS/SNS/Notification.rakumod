use JSON::Class;
use JSON::Name;

=begin pod

=head1 NAME

AWS::SNS::Notification - Description of an AWS Simple Notification Service message.

=head1 SYNOPSIS

=begin code
use Cro::HTTP::Router;
use Cro::HTTP::Server;
use AWS::SNS::Notification;


my $app = route {
    post -> 'sns-message' {
        # The SNS message has a content-type of 'text/plain' so this will be raw JSON
        request-body -> $json {
            my $notification = AWS::SNS::Notification.from-json($json);
            # Check this is a valid notification
            if $notification.verify-signature {
               if $notification.is-notification {
                   # Do something with the $notification.message
                   # The format of which depends on the source - an S3 notification will be a JSON String for instance
               }
               else {
                   # This is subscribe or unsubscribe confirmation request
                   # so perform the confirmation
                   $notification.respond;
               }
            }
            else {
                bad-request 'text/plain', 'Fake notification';
            }
        }
    }
};

my Cro::Service $service = Cro::HTTP::Server.new(:host<127.0.0.1>, :port<7798>, application => $app);

$service.start;

react  { whenever signal(SIGINT) { $service.stop; exit; } }
=end code

=head1 DESCRIPTION

This class describes an L<AWS Simple Notification Service|https://aws.amazon.com/sns/>
message that may be delivered by HTTPS or by a message queue or somesuch.

The class provides for parsing the JSON payload for the message, verifying
the signature of the message against the signing key and responding if
necessary to a Subscribe or Unsubscribe confirmation.

The actual message sent by the source application is accessed through the
C<.message> accessor - so for instance in the case of an S3 notification
this will be a JSON string which will need to be decoded for further
processing.

=end pod

class AWS::SNS::Notification does JSON::Class {
    use URI;
    use Base64;
    use OpenSSL::RSATools;
    use Cro::HTTP::Client;

    has Str $.token             is json-name('Token');
    has Str $.message-id        is json-name('MessageId');
    has Str $.timestamp         is json-name('Timestamp');
    has Str $.signature         is json-name('Signature');
    has Str $.signature-version is json-name('SignatureVersion');
    has Str $.subject           is json-name('Subject');
    has Str $.topic-arn         is json-name('TopicArn');
    has Str $.type              is json-name('Type');
    has Str $.signing-cert-url  is json-name('SigningCertURL');
    has Str $.subscribe-url     is json-name('SubscribeURL');
    has Str $.message           is json-name('Message');

    #| A constructor that accepts an Associate positional argument which should be
    #| the decoded JSON of the message. Other named arguments can be provided.
    multi method new(%args, |c ) {
        my %a = self.attribute-aliases;

        my %real-args;
        for %args.kv -> $k, $v {
            if %a{$k} -> $real-name  {
                %real-args{$real-name} = $v;
            }
            else {
                %real-args{$k} = $v;
            }
        }
        self.new(|%real-args, |c );
    }

    #| Returns true if this a subscription confirmation
    method is-subscribe( --> Bool) {
        $!type eq 'SubscriptionConfirmation'
    }

    #| Returns true if this is an unsubscribe confirmation
    method is-unsubscribe( --> Bool) {
        $!type eq 'UnsubscribeConfirmation'
    }

    #| Returns true if this is an actual notification message
    method is-notification( --> Bool) {
        $!type eq 'Notification'
    }

    #| A Cro::HTTP::Client object, this can be set to over-ride the
    #| default with say a proxy or similar.
    has Cro::HTTP::Client $.ua;

    method ua( --> Cro::HTTP::Client ) handles <get-body> {
        $!ua //= Cro::HTTP::Client.new;
    }

    method attribute-aliases() {
        self.^attributes.grep(JSON::Name::NamedAttribute).map( -> $a { $a.json-name => $a.name.substr(2)}).Hash;
    }

    #| For a 'subscribe' or 'unsubscribe' message this should be called to confirm the action
    #| It will return a Promise that will be kept when the action is completed.
    method respond( --> Promise ) {
        if ($.is-subscribe || $.is-unsubscribe ) && $.subscribe-url.defined {
            my $subscribe-url = URI.new($.subscribe-url);
            my %q = $subscribe-url.query.Hash;
            $subscribe-url.query('');
            self.get-body($subscribe-url.Str, query => %q);
        }
        else {
            Promise.kept;
        }
    }

    #| This is the text of the signing certificate, it will typically be retrieved from the URL provided
    #| in the message, but could be over-ridden for testing or other reasons.
    has Str $.signing-certificate;

    method signing-certificate( --> Str ) {
        $!signing-certificate //= await self.get-body($.signing-cert-url);
    }

    method signing-fields() {
        if $.is-notification {
            <Message MessageId Subject Timestamp TopicArn Type>
        }
        else {
            <Message MessageId SubscribeURL Timestamp Token TopicArn Type>
        }
    }

    has Str $.signing-string;

    method signing-string( --> Str ) {
        $!signing-string //= do {
            my $n = any(self.signing-fields);
            self.^attributes.grep( -> $a { $a ~~ JSON::Name::NamedAttribute && $a.json-name.defined && $a.json-name eq $n }).map( -> $v { $v.json-name => $v.get_value(self) }).sort(*.key).map(-> $p { ($p.key, $p.value ).join("\n") }).join("\n") ~ "\n";
        }
    }

    has Blob $.decoded-signature;

    method decoded-signature( --> Blob ) {
        $!decoded-signature //= decode-base64(self.signature, :bin);
    }

    has OpenSSL::RSAKey $.rsa;

    method rsa( --> OpenSSL::RSAKey ) {
        $!rsa  //= OpenSSL::RSAKey.new(x509-pem => self.signing-certificate);
    }

    my regex aws-region {
        <[a .. z]> ** 2 "-" <[a .. z \-]>+ "-" <[ 0 .. 9]>+
    }

    my token dot {
        '.'
    }

    my token sns {
        sns
    }

    my token amazonaws {
        amazonaws
    }

    my token com {
        com
    }

    my regex cn {
        <dot>cn
    }

    my regex aws-sns-host {
         ^ <sns><dot><aws-region><dot><amazonaws><dot><com><cn>? $
    }

    #| This returns a Boolean to indicate whether the URL from which the signing certificate
    #| will be retrieved is a valid amazon URL.
    method validate-certificate-url( --> Bool ) {
        my URI $uri = URI.new($.signing-cert-url);

        my Bool $rc = False;

        if $uri.host -> $host {
            if $host ~~ /<aws-sns-host>/ {
                $rc = True;
            }
        }
        $rc;
    }

    #| This will check that the signature provided in the message is valid for the
    #| content of the message and the specified certificate.  The certificate URL
    #| will be validated before attempting to retrieve and use the certificate: if
    #| the ':!validate-url' is supplied this check will not be performed.
    method verify-signature( Bool :$validate-url = True --> Bool ) {
        if !$validate-url || $.validate-certificate-url {
            self.rsa.verify($.signing-string.encode, $.decoded-signature, :sha1);
        }
        else {
            False
        }
    }
}
