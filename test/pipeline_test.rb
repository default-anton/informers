require_relative "test_helper"

class PipelineTest < Minitest::Test
  def test_ner
    ner = Informers.pipeline("ner")
    result = ner.("Ruby is a programming language created by Matz")
    assert_equal 1, result.size
    assert_equal "PER", result[0][:entity_group]
    assert_in_delta 0.994, result[0][:score]
    assert_equal "Matz", result[0][:word]
    assert_equal 42, result[0][:start]
    assert_equal 46, result[0][:end]
  end

  def test_ner_aggregation_strategy
    ner = Informers.pipeline("ner")
    result = ner.("Ruby is a programming language created by Matz", aggregation_strategy: "none")
    assert_equal 2, result.size
    assert_equal "B-PER", result[0][:entity]
    assert_in_delta 0.996, result[0][:score]
    assert_equal 8, result[0][:index]
    assert_equal "Mat", result[0][:word]
    assert_equal 42, result[0][:start]
    assert_equal 45, result[0][:end]
  end

  def test_sentiment_analysis
    classifier = Informers.pipeline("sentiment-analysis")
    result = classifier.("I love transformers!")
    assert_equal "POSITIVE", result[:label]
    assert_in_delta 0.9997887, result[:score], 0.0000001

    result = classifier.("This is super cool")
    assert_equal "POSITIVE", result[:label]
    assert_in_delta 0.9998608, result[:score], 0.0000001

    result = classifier.(["This is super cool", "I didn't like it"])
    assert_equal "POSITIVE", result[0][:label]
    assert_in_delta 0.9998600, result[0][:score], 0.0000001
    assert_equal "NEGATIVE", result[1][:label]
    assert_in_delta 0.9985375, result[1][:score], 0.0000001
  end

  def test_question_answering
    qa = Informers.pipeline("question-answering")
    result = qa.("Who invented Ruby?", "Ruby is a programming language created by Matz")
    assert_in_delta 0.998, result[:score]
    assert_equal "Matz", result[:answer]
    assert_equal 42, result[:start]
    assert_equal 46, result[:end]
  end

  def test_zero_shot_classification
    classifier = Informers.pipeline("zero-shot-classification")
    text = "Last week I upgraded my iOS version and ever since then my phone has been overheating whenever I use your app."
    labels = ["mobile", "billing", "website", "account access"]
    result = classifier.(text, labels)
    assert_equal text, result[:sequence]
    assert_equal ["mobile", "billing", "account access", "website"], result[:labels]
    assert_elements_in_delta [0.633, 0.134, 0.121, 0.111], result[:scores]
  end

  def test_fill_mask
    unmasker = Informers.pipeline("fill-mask")
    result = unmasker.("Paris is the [MASK] of France.")
    assert_equal 5, result.size
    assert_in_delta 0.997, result[0][:score]
    assert_equal 3007, result[0][:token]
    assert_equal "capital", result[0][:token_str]
    assert_equal "paris is the capital of france.", result[0][:sequence]
  end

  def test_fill_mask_no_mask_token
    unmasker = Informers.pipeline("fill-mask")
    error = assert_raises(ArgumentError) do
      unmasker.("Paris is the <mask> of France.")
    end
    assert_equal "Mask token ([MASK]) not found in text.", error.message
  end

  def test_feature_extraction
    sentences = ["This is an example sentence", "Each sentence is converted"]
    extractor = Informers.pipeline("feature-extraction")
    output = extractor.(sentences)
    assert_in_delta (-0.0145), output[0][0][0]
    assert_in_delta (-0.3130), output[-1][-1][-1]
  end

  def test_embedding
    sentences = ["This is an example sentence", "Each sentence is converted"]
    embed = Informers.pipeline("embedding")
    embeddings = embed.(sentences)
    assert_elements_in_delta [0.067657, 0.063496, 0.048713], embeddings[0][..2]
    assert_elements_in_delta [0.086439, 0.10276, 0.0053946], embeddings[1][..2]
  end

  def test_reranking
    query = "How many people live in London?"
    docs = ["Around 9 Million people live in London", "London is known for its financial district"]
    rerank = Informers.pipeline("reranking")
    result = rerank.(query, docs)
    assert_equal 2, result.size
    assert_equal 0, result[0][:doc_id]
    assert_in_delta 0.984, result[0][:score]
    assert_equal 1, result[1][:doc_id]
    assert_in_delta 0.139, result[1][:score]
  end

  def test_image_classification
    classifier = Informers.pipeline("image-classification")
    result = classifier.("test/support/pipeline-cat-chonk.jpeg", top_k: 2)
    assert_equal "lynx, catamount", result[0][:label]
    assert_in_delta 0.428, result[0][:score], 0.01
    assert_equal "cougar, puma, catamount, mountain lion, painter, panther, Felis concolor", result[1][:label]
    assert_in_delta 0.047, result[1][:score], 0.01
  end

  def test_zero_shot_image_classification
    classifier = Informers.pipeline("zero-shot-image-classification")
    result = classifier.("test/support/pipeline-cat-chonk.jpeg", ["dog", "cat", "tiger"])
    assert_equal 3, result.size
    assert_equal "cat", result[0][:label]
    assert_in_delta 0.756, result[0][:score]
    assert_equal "tiger", result[1][:label]
    assert_in_delta 0.189, result[1][:score]
    assert_equal "dog", result[2][:label]
    assert_in_delta 0.055, result[2][:score]
  end

  def test_image_feature_extraction
    fe = Informers.pipeline("image-feature-extraction")
    result = fe.("test/support/pipeline-cat-chonk.jpeg")
    assert_in_delta 0.877, result[0][0], 0.01
  end

  def test_progress_callback
    msgs = []
    extractor = Informers.pipeline("feature-extraction", progress_callback: ->(msg) { msgs << msg })
    extractor.("I love transformers!")

    expected_msgs = [
      {status: "initiate", name: "Xenova/all-MiniLM-L6-v2", file: "tokenizer.json"},
      {status: "ready", task: "feature-extraction", model: "Xenova/all-MiniLM-L6-v2"}
    ]
    expected_msgs.each do |expected|
      assert_includes msgs, expected
    end
  end
end
