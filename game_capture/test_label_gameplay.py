import pytest
from PIL import Image
import label_gameplay as labeler


@pytest.fixture
def sample(tmp_path, monkeypatch):
    monkeypatch.setattr(labeler, 'DATA', tmp_path/'dataset')
    path = tmp_path/'screenshot.png'
    Image.new('RGB', (160,90), 'green').save(path)
    return path


def test_match_cannot_cross_splits(sample):
    labeler.import_files([sample], 'match_01', 'train')
    with pytest.raises(ValueError, match='another split'):
        labeler.import_files([sample], 'match_01', 'test')
    assert labeler.read_rows()[0]['split'] == 'train'


def test_identical_image_cannot_leak_to_another_match(sample):
    labeler.import_files([sample], 'match_01', 'train')
    labeler.import_files([sample], 'match_02', 'test')
    assert len(labeler.read_rows()) == 1


def test_empty_labels_require_explicit_confirmation(sample):
    labeler.import_files([sample], 'match_01', 'train')
    name = labeler.read_rows()[0]['fname']
    with pytest.raises(ValueError, match='confirm'):
        labeler.save_review(name, [])
    assert labeler.read_rows()[0]['status'] == 'unreviewed'
    labeler.save_review(name, [], no_units=True)
    assert labeler.read_rows()[0]['status'] == 'reviewed'


def test_conflicting_or_unknown_labels_rejected(sample):
    labeler.import_files([sample], 'match_01', 'validation')
    name = labeler.read_rows()[0]['fname']
    with pytest.raises(ValueError):
        labeler.save_review(name, ['Orc Grunt'], no_units=True)
    with pytest.raises(ValueError, match='Unknown'):
        labeler.save_review(name, ['Not a unit'])
    assert labeler.read_rows()[0]['status'] == 'unreviewed'


def test_uncertain_images_remain_separate_from_reviewed_labels(sample):
    labeler.import_files([sample], 'match_01', 'test')
    name = labeler.read_rows()[0]['fname']
    with pytest.raises(ValueError, match='reason'):
        labeler.save_review(name, [], exclude=True)
    labeler.save_review(name, [], exclude=True, note='Overlapping units cannot be identified')
    row = labeler.read_rows()[0]
    assert row['status'] == 'excluded'
    assert row['labels'] == ''


def test_builds_local_labeling_interface():
    app = labeler.build_app()
    assert any(component.get('props',{}).get('label') == 'Every visible unit TYPE from the list; do not count units'
               for component in app.config['components'])
    app.close()
