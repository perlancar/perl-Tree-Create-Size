package Tree::Create::Size;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter::Rinci qw(import);

our %SPEC;

$SPEC{create_tree} = {
    v => 1.1,
    summary => 'Create a tree object of certain size',
    description => <<'_',

This routine creates a tree object of certain size/dimension. You need to supply
either `height` and `num_children`, or `num_nodes_per_level`.

_
    args_rels => {
        choose_one => ['height', 'num_nodes_per_level'],
        choose_all => ['height', 'num_children'],
    },
    args => {
        height => {
            summary => 'Height of tree',
            schema => ['int*', min=>0],
            description => <<'_',

Height of 0 means the tree only consists of the root node. Height of 1 means the
tree consists of root node and its children. Height of 2 increases this with the
children's children. And so on.

_
        },
        num_children => {
            summary => 'Number of children for each node',
            schema => ['int*', min=>1],
        },
        num_nodes_per_level => {
            schema => ['array*', of=>['int*', min=>1], min_len=>0],
            summary => 'Number of nodes per level',
            description => <<'_',

This argument specifies number of nodes per level and should be an array. The
first element of the array corresponds to the total number of children nodes
below the root node (i.e. the total number of nodes at level 1), the second
element of the array corresponds to the total number of all that children's
children (i.e. the total number of nodes at level 2, *not* the number of
children for each child), and so on.

The children will be distributed evenly among the parents.

_
        },
        class => {
            summary => 'Perl class name',
            schema => 'str*', # XXX perl_classname
            description => <<'_',

Any class will do as long as it responds to `parent` and `children`. See the
`Role::TinyCommons::Tree::Node` for more details on the requirement.

_
        },
        code_create_node => {
            schema => 'code*',
            description => <<'_',

By default, node object will be created with:

    $class->new()

you can customize this by providing a routine to instantiate the node. The code
will receive:

    ($class, $level, $parent)

where `$class` is the class name (your code can naturally create nodes using any
class you want), `$level` is the current level (0 for root node, 1 for its
children, and so on), `$parent` is the parent node object. The code should
return the node object.

Your code need not set the node's `parent()`, connecting parent and children
nodes will be performed by this routine.

Example:

    sub {
        ($class, $level, $parent) = @_;
        $class->new( attr => 10*rand );
    }

_
        },
    },
    result_naked => 1,
};
sub create_tree {
    my %args = @_;

    my $num_nodes_per_level;
    if ($args{num_nodes_per_level}) {
        $num_nodes_per_level = $args{num_nodes_per_level};
    } else {
        $num_nodes_per_level = [];
        my $n = $args{num_children};
        for (1..$args{height}) {
            push @$num_nodes_per_level, $n;
            $n *= $args{num_children};
        }
    }
    $num_nodes_per_level
        or die "Please specify height + num_children or num_nodes_per_level";
    my $class = $args{class} or die "Please specify 'class'";

    my $code_create0 = $args{code_create_node};
    my $code_create  = sub {
        my ($level, $parent) = @_;
        my $node;
        if ($code_create0) {
            $node = $code_create0->($class, $level, $parent);
        } else {
            $node = $class->new;
        }
        # connect node with its parent
        $node->parent($parent) if $parent;
        $node;
    };

    my $root = $code_create->(0, undef);

    my @parents = ($root);
    for my $level (1 .. @$num_nodes_per_level) {
        my $num_nodes = $num_nodes_per_level->[$level-1];
        my @children; # key = index parent, val = [child, ...]
        for my $i (1..$num_nodes) {
            my $parent_idx = int(($i-1)/$num_nodes * @parents);
            my $parent = $parents[$parent_idx];
            $children[$parent_idx] //= [];
            my $child = $code_create->($level, $parent);
            push @{ $children[$parent_idx] }, $child;
        }
        # connect parent with its children
        for my $i (0..$#parents) {
            $parents[$i]->children($children[$i] // []);
        }

        @parents = map { @{ $children[$_] // [] } } 0..$#parents;
    }

    $root;
}

1;
# ABSTRACT:

=head1 SYNOPSIS

 use Tree::Create::Size qw(create_tree);
 use MyNode;

 my $tree = create_tree(

     # either specify height + num_children ... (e.g. this will create a tree
     # with 1 + 2 + 4 + 8 + 16 nodes).
     height => 4,
     num_children => 2,

     # ... or specify num_nodes_per_level, e.g.
     num_nodes_per_level => [100, 3000, 5000, 8000, 3000, 1000, 300],

     class => 'MyNode',
     # optional
     #code_create_node => sub {
     #    my ($class, $level, $parent) = @_;
     #    $class->new(...);
     #},
 );


=head1 SEE ALSO

L<Role::TinyCommons::Tree::Node>

Other modules to create tree: L<Tree::FromStruct>, L<Tree::FromText>,
L<Tree::FromTextLines>, L<Tree::Create::Callback>.
