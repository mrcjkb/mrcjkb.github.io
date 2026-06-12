{-# LANGUAGE OverloadedStrings #-}

import  Data.Map qualified as Map
import  Hakyll
import  Prelude
import  Skylighting.Types (Style (..), TokenStyle (..), Color, ToColor (..), TokenType (..), defStyle)
import  Text.Pandoc.Highlighting
import  Text.Pandoc.Options (WriterOptions (..))

main :: IO ()
main = hakyll  do
    match "images/*"  do
        route   idRoute
        compile copyFileCompiler

    match "files/*"  do
        route   idRoute
        compile copyFileCompiler

    match "css/*"  do
        route   idRoute
        compile compressCssCompiler

    match "CNAME"  do
        route   idRoute
        compile copyFileCompiler

    match (fromList ["about.rst", "contact.markdown"])  do
        route   $ setExtension "html"
        compile $ pandocCompiler'
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    match "cv.html"  do
        route idRoute
        compile $ getResourceBody
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    match "posts/*"  do
        route $ setExtension "html"
        compile $ pandocCompiler'
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    create ["archive.html"]  do
        route idRoute
        compile  do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Archives"            `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    create ["css/syntax.css"] do
      route idRoute
      compile  do
        makeItem $ styleToCss pandocCodeStyle

    create ["atom.xml"] do
      route idRoute
      compile $ mkFeed renderAtom

    create ["rss.xml"] do
      route idRoute
      compile $ mkFeed renderRss


    match "index.html"  do
        route idRoute
        compile  do
            posts <- recentFirst =<< loadAll "posts/*"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateBodyCompiler


--------------------------------------------------------------------------------

postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext

pandocCodeStyle :: Style
pandocCodeStyle = catppuccinMocha

pandocCompiler' :: Compiler (Item String)
pandocCompiler' =
  pandocCompilerWith
    defaultHakyllReaderOptions
    defaultHakyllWriterOptions
      { writerHighlightStyle   = Just pandocCodeStyle
      }

type FeedRenderer = FeedConfiguration -> Context String -> [Item String] -> Compiler (Item String)

mkFeed :: FeedRenderer -> Compiler (Item String)
mkFeed render = do
    let feedCtx = postCtx `mappend` bodyField "description"
        feedConfiguration = FeedConfiguration
          { feedTitle       = "mrcjkb"
          , feedDescription = "My Hakyll site"
          , feedAuthorName  = "Marc Jakobi"
          , feedAuthorEmail = "marc@jakobi.dev"
          , feedRoot        = "mrcjkb.dev"
          }
    posts <- fmap (take 10) . recentFirst =<< loadAllSnapshots "posts/*" "content"
    render feedConfiguration feedCtx posts

catppuccinMocha :: Style
catppuccinMocha = Style{
    backgroundColor = Nothing
  , defaultColor = Nothing
  , lineNumberColor = color 0xcdd6f4
  , lineNumberBackgroundColor = Nothing
  , tokenStyles = Map.fromList
    [ (KeywordTok, defStyle{ tokenColor = color 0xcba6f7 })
    , (FunctionTok, defStyle{ tokenColor = color 0x89b4fa })
    , (OperatorTok, defStyle{ tokenColor = color 0x74c7ec })
    , (CharTok, defStyle{ tokenColor = color 0xa6e3a1 })
    , (StringTok, defStyle{ tokenColor = color 0xa6e3a1 })
    , (CommentTok, defStyle{ tokenColor = color 0x9399b2 })
    , (OtherTok, defStyle{ tokenColor = color 0xcdd6f4 })
    , (AlertTok, defStyle{ tokenColor = color 0xf38ba8 })
    , (ErrorTok, defStyle{ tokenColor = color 0xf38ba8, tokenBold = True })
    , (WarningTok, defStyle{ tokenColor = color 0xfab387, tokenBold = True })
    , (DataTypeTok, defStyle{ tokenColor = color 0xf9e2af, tokenBold = True })
    , (ConstantTok, defStyle)
    , (SpecialCharTok, defStyle{ tokenColor = color 0x94e2d5 })
    , (VerbatimStringTok, defStyle{ tokenColor = color 0x94e2d5 })
    , (SpecialStringTok, defStyle{ tokenColor = color 0x94e2d5 })
    , (ImportTok, defStyle)
    , (VariableTok, defStyle{ tokenColor = color 0xb4befe })
    , (ControlFlowTok, defStyle{ tokenColor = color 0x89b4fa })
    , (OperatorTok, defStyle)
    , (BuiltInTok, defStyle)
    , (ExtensionTok, defStyle)
    , (PreprocessorTok, defStyle{ tokenColor = color 0xf38ba8 })
    , (DocumentationTok, defStyle{ tokenColor = color 0xa6e3a1 })
    , (AnnotationTok, defStyle{ tokenColor = color 0xa6e3a1 })
    , (CommentVarTok, defStyle{ tokenColor = color 0xa6e3a1 })
    , (AttributeTok, defStyle)
    , (InformationTok, defStyle{ tokenColor = color 0xa6e3a1 })
    ]
  }
  where
   color :: Int -> Maybe Color
   color = toColor
