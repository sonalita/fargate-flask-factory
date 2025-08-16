from aws_cdk import Tags


def apply_default_tags(scope):
    # In a real application these would come from YAML etc.
    tags = {
        'Owner': 'Me',
        'Name': 'Hello-world',
        'Environment': 'Dev',
    }
    for key, value in tags.items():
        Tags.of(scope).add(key, value)
