module FeedPrompts
  module_function

  # Return summary as-is, trusting the AI to respect the maxLength constraint
  # The JSON schema enforces the character limit, so no manual truncation needed
  def truncate_summary(text, _max_length = 140)
    text.to_s.strip
  end

  def title_guidelines
    <<~TEXT
      TITLE GUIDELINES (8-12 words):
      - Write like you're posting to Reddit or telling a friend about it
      - Use sentence case: only capitalize the first word (and proper nouns like names, places, products)
      - Be specific and conversational - avoid corporate jargon
      - Lead with the interesting part - what would make someone click?
      - Can use numbers, quotation marks, or casual language to add personality
      - Examples (good):
        ✓ "Made $900 in 3 days offering snow removal with just a shovel"
        ✓ "Poop scooping company bringing in $1,700/month, 15 hours a week"
        ✓ "Marketing is way harder than writing the actual code"
      - Examples (bad):
        ✗ "Sales Job Drama - Visa Issues And Commission Struggles" (title case)
        ✗ "Discussion About Marketing Challenges" (too vague, boring)
    TEXT
  end

  def summary_guidelines
    <<~TEXT
      SUMMARY GUIDELINES (STRICT: 140 characters max, one or two sentences):
      - CRITICAL: Must be 140 characters or less AND end with a complete thought. Count characters carefully.
      - Do not cut off mid-sentence or mid-word - complete the thought within the limit
      - Casual and conversational, like explaining it to a friend
      - What actually happened, skip the corporate speak
      - Third person is fine, but keep it natural
      - Specific details over generic descriptions
      - If you're approaching the limit, wrap up the sentence naturally
      - Examples (good):
        ✓ "Made $200 clearing an apartment complex driveway in 4 hours. Calls kept coming but had to turn down bigger jobs." (120 chars)
        ✓ "Building a product is easy. Getting anyone to actually care about it feels like hitting a wall over and over." (114 chars)
      - Examples (bad):
        ✗ "Community member shares strategic insights regarding customer acquisition optimization." (too formal/corporate)
        ✗ "An interesting discussion ensued." (vague, boring)
    TEXT
  end

  def key_insight_guidelines
    <<~TEXT
      KEY_INSIGHT (2-4 words, 20 characters max):
      - Ultra-short room name
      - Captures core topic
      - Casual and direct
      - Examples:
        ✓ "Snow removal win"
        ✓ "Marketing struggles"
        ✓ "Asset protection"
        ✓ "Remote robots debate"
        ✗ "Discussion about sales" (too long)
        ✗ "A conversation" (too generic)
    TEXT
  end

  def preview_message_guidelines
    <<~TEXT
      PREVIEW_MESSAGE_ID (optional - can be null):
      - Select a message that adds visual or contextual value beyond the title/summary
      - Aim for 40-60% of conversations to have a preview
      - Prioritize messages with rich media (links, images) as they create visual interest
      
      PRIORITIZE IN THIS ORDER:
      
      1. MESSAGES WITH LINKS (HIGH PRIORITY):
         - Messages with [LINK_PREVIEW] are visually rich and add context
         - Links to articles, tools, products, news, research, announcements
         - Even tangentially related links can be valuable if they're interesting
         - Links provide visual previews (images, titles) that enhance the card
      
      2. MESSAGES WITH ATTACHMENTS (HIGH PRIORITY):
         - Messages with [HAS_ATTACHMENT] provide visual content
         - Images, screenshots, files add richness to the card
      
      3. COMPELLING TEXT MESSAGES (MEDIUM PRIORITY):
         - Specific numbers/stats that aren't in the summary ("$900 in 3 days", "2,230 clicks")
         - The question or statement that sparked the conversation
         - Surprising quotes or pivotal moments
         - Concrete details that add flavor
      
      WHEN TO RETURN NULL (40-60% of conversations):
      - Pure reactions: "that's crazy", "interesting", "makes sense"
      - Simple agreements: "Congrats!", "I agree", "Great point"
      - Messages that just restate the title
      - Very long text without a clear hook (>400 chars)
      - When there's no media and no particularly compelling message
      
      DECISION PROCESS:
      1. First, look for messages with [LINK_PREVIEW] or [HAS_ATTACHMENT] - these add visual richness
      2. If found, prefer these unless they're completely irrelevant
      3. If no media, look for the most compelling text message:
         - Specific numbers or stats
         - The question that sparked discussion
         - A surprising or pivotal moment
      4. If nothing stands out AND no media, return null
      5. When close call between media and great text, prefer media (visual interest)
      
      Return just the message ID number (e.g., 123), not the full [ID: 123] format, or null.
    TEXT
  end

  def conversation_completeness_instructions
    <<~TEXT
      CRITICAL: Include ALL messages that form the COMPLETE conversation. A reader should be able to follow the ENTIRE story from beginning to end without missing ANY parts of the discussion.

      HOW TO IDENTIFY A COMPLETE CONVERSATION:
      
      1. START with the core messages and participants
      2. FIND all messages from participants who engage with this topic
      3. FOLLOW the chronological discussion flow - if people keep talking about related points, it's ONE conversation
      4. INCLUDE the entire discussion arc until participants stop engaging or topic completely changes
      
      CONVERSATIONS EVOLVE - THIS IS NORMAL:
      Example flow: "AI robots" → "skepticism about adoption" → "remote-controlled robots" → "labor market impact" → "comparison to Uber"
      ✅ This is ONE conversation - include ALL messages in this flow
      ✗ Do NOT fragment just because subtopics emerged
      
      ABSOLUTE INCLUSION RULES (ALWAYS include if these apply):
      1. ANY message from participants actively engaged in the discussion
      2. ANY response or follow-up from someone in the conversation
      3. ALL messages in a continuous chronological sequence on the same general topic area
      4. ANY message that references, builds on, or responds to previous messages
      5. ALL thread replies if the conversation includes threads
      6. ALL questions AND their answers within the discussion
      7. ANY message that introduces a related point or subtopic that others then discuss
      8. ALL messages between the first relevant message and the last relevant message chronologically
      
      CONVERSATIONAL MARKERS (strong signals to INCLUDE):
      - Someone responds to a previous point (even hours later)
      - Someone asks a question and others answer
      - Someone shares a link/example related to the discussion
      - Someone says "also", "but", "however", "actually" - connecting to previous points
      - Someone uses pronouns (it, they, that) referring to something mentioned earlier
      - Reactions/emojis on messages in the conversation
      
      ONLY EXCLUDE if message meets ALL these criteria:
      - Posted by someone NOT participating in the main discussion
      - About a completely unrelated topic (not just a subtopic or tangent)
      - No conversational connection to any message in the discussion
      - Would genuinely confuse reader if included
      
      DEFAULT RULE: When in ANY doubt, INCLUDE the message. Completeness is more important than brevity.
      A conversation can span 20+ messages - this is EXPECTED and DESIRED.
    TEXT
  end
end
