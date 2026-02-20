---
name: prompt-engineering-patterns
description: Master advanced prompt engineering techniques to maximize LLM performance, reliability, and controllability.
---

# Prompt Engineering Patterns

Master advanced prompt engineering techniques to maximize LLM performance, reliability, and controllability.

## Core Capabilities

### 1. Few-Shot Learning

- Example selection strategies (semantic similarity, diversity sampling)
- Balancing example count with context window constraints
- Constructing effective demonstrations with input-output pairs
- Dynamic example retrieval from knowledge bases
- Handling edge cases through strategic example selection

### 2. Chain-of-Thought Prompting

- Step-by-step reasoning elicitation
- Zero-shot CoT with "Let's think step by step"
- Few-shot CoT with reasoning traces
- Self-consistency techniques (sampling multiple reasoning paths)
- Verification and validation steps

### 3. Structured Outputs

- JSON mode for reliable parsing
- Pydantic schema enforcement
- Type-safe response handling
- Error handling for malformed outputs

### 4. Prompt Optimization

- Iterative refinement workflows
- A/B testing prompt variations
- Measuring prompt performance metrics (accuracy, consistency, latency)
- Reducing token usage while maintaining quality
- Handling edge cases and failure modes

### 5. Template Systems

- Variable interpolation and formatting
- Conditional prompt sections
- Multi-turn conversation templates
- Role-based prompt composition
- Modular prompt components

### 6. System Prompt Design

- Setting model behavior and constraints
- Defining output formats and structure
- Establishing role and expertise
- Safety guidelines and content policies
- Context setting and background information

## Key Patterns

### Pattern 1: Structured Output with Pydantic

```python
from anthropic import Anthropic
from pydantic import BaseModel, Field
from typing import Literal
import json

class SentimentAnalysis(BaseModel):
    sentiment: Literal["positive", "negative", "neutral"]
    confidence: float = Field(ge=0, le=1)
    key_phrases: list[str]
    reasoning: str

async def analyze_sentiment(text: str) -> SentimentAnalysis:
    """Analyze sentiment with structured output."""
    client = Anthropic()
    message = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=500,
        messages=[{
            "role": "user",
            "content": f"""Analyze the sentiment of this text.
Text: {text}

Respond with JSON matching this schema:
{{
  "sentiment": "positive" | "negative" | "neutral",
  "confidence": 0.0-1.0,
  "key_phrases": ["phrase1", "phrase2"],
  "reasoning": "brief explanation"
}}"""
        }]
    )
    return SentimentAnalysis(**json.loads(message.content[0].text))
```

### Pattern 2: Chain-of-Thought with Self-Verification

```python
from langchain_core.prompts import ChatPromptTemplate

cot_prompt = ChatPromptTemplate.from_template("""
Solve this problem step by step.

Problem: {problem}

Instructions:
1. Break down the problem into clear steps
2. Work through each step showing your reasoning
3. State your final answer
4. Verify your answer by checking it against the original problem

Format your response as:
## Steps
[Your step-by-step reasoning]

## Answer
[Your final answer]

## Verification
[Check that your answer is correct]
""")
```

### Pattern 3: Few-Shot with Dynamic Example Selection

```python
from langchain_voyageai import VoyageAIEmbeddings
from langchain_core.example_selectors import SemanticSimilarityExampleSelector
from langchain_chroma import Chroma

# Create example selector with semantic similarity
example_selector = SemanticSimilarityExampleSelector.from_examples(
    examples=[
        {"input": "How do I reset my password?", "output": "Go to Settings > Security > Reset Password"},
        {"input": "Where can I see my order history?", "output": "Navigate to Account > Orders"},
        {"input": "How do I contact support?", "output": "Click Help > Contact Us or email support@example.com"},
    ],
    embeddings=VoyageAIEmbeddings(model="voyage-3-large"),
    vectorstore_cls=Chroma,
    k=2  # Select 2 most similar examples
)

async def get_few_shot_prompt(query: str) -> str:
    """Build prompt with dynamically selected examples."""
    examples = await example_selector.aselect_examples({"input": query})
    examples_text = "\n".join(
        f"User: {ex['input']}\nAssistant: {ex['output']}"
        for ex in examples
    )
    return f"""You are a helpful customer support assistant.
Here are some example interactions:
{examples_text}

Now respond to this query:
User: {query}
Assistant:"""
```

### Pattern 4: Progressive Disclosure

Start with simple prompts, add complexity only when needed:

```python
PROMPT_LEVELS = {
    # Level 1: Direct instruction
    "simple": "Summarize this article: {text}",

    # Level 2: Add constraints
    "constrained": """Summarize this article in 3 bullet points, focusing on:
- Key findings
- Main conclusions
- Practical implications

Article: {text}""",

    # Level 3: Add reasoning
    "reasoning": """Read this article carefully.
1. First, identify the main topic and thesis
2. Then, extract the key supporting points
3. Finally, summarize in 3 bullet points

Article: {text}
Summary:""",

    # Level 4: Add examples
    "few_shot": """Read articles and provide concise summaries.

Example:
Article: "New research shows that regular exercise can reduce anxiety by up to 40%..."
Summary:
• Regular exercise reduces anxiety by up to 40%
• 30 minutes of moderate activity 3x/week is sufficient
• Benefits appear within 2 weeks of starting

Now summarize this article:
Article: {text}
Summary:"""
}
```
