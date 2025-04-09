{-# LANGUAGE OverloadedStrings #-}

import           Hakyll
import           Prelude
import           Text.Pandoc.Highlighting
import           Text.Pandoc.Options      (WriterOptions (..))

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
pandocCodeStyle = haddock

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

